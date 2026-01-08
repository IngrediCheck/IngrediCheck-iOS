import Foundation
import SwiftUI
import UIKit
import CryptoKit
import Supabase
import PostHog
import Network
import CoreTelephony

enum NetworkError: Error {
    case invalidResponse(Int)
    case badUrl
    case decodingError
    case authError
    case notFound(String)
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

enum ImageSize {
    case small
    case medium
    case large
}

enum UnifiedAnalysisInput {
    case barcode(String)
    case productImages([ProductImage])
}

struct UnifiedAnalysisStreamError: Error, LocalizedError {
    let message: String
    let statusCode: Int?

    var errorDescription: String? { message }
}

struct ScanStreamError: Error, LocalizedError {
    let message: String
    let statusCode: Int?
    var errorDescription: String? { message }
}

@Observable final class WebService {
    
    private let smallImageStore: FileStore
    private let mediumImageStore: FileStore
    private let largeImageStore: FileStore

    init() {
        self.smallImageStore =
            FileCache(
                cacheName: "smallproductimages",
                maximumDiskUsage: (256*1024*1024),
                fileStore: ImageFileStore(resize: CGSize(width: 256, height: 0))
            )
        
        self.mediumImageStore =
            FileCache(
                cacheName: "mediumproductimages",
                maximumDiskUsage: (512*1024*1024),
                fileStore: ImageFileStore(resize: CGSize(width: 512, height: 0))
            )
        
        self.largeImageStore =
            FileCache(
                cacheName: "largeproductimages",
                maximumDiskUsage: (512*1024*1024),
                fileStore: ImageFileStore(resize: nil)
            )
    }
    
    func fetchImage(imageLocation: DTO.ImageLocationInfo, imageSize: ImageSize) async throws -> UIImage {
        
        let fileLocation: FileLocation
        switch imageLocation {
        case .url(let url):
            fileLocation = FileLocation.url(url)
            
        case .imageFileHash(let imageFileHash):
            // Heuristic: memoji images live in the `memoji-images` bucket and include
            // a year/month path segment (e.g. "2025/01/<hash>.png"). Product images
            // are flat hashes without slashes.
            if imageFileHash.contains("/") {
                // For memoji images in public bucket, use public URL directly
                // Format: https://<project>.supabase.co/storage/v1/object/public/memoji-images/<path>
                // URL-encode each path segment to handle special characters properly
                let pathComponents = imageFileHash.split(separator: "/")
                let encodedComponents = pathComponents.map { component in
                    component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
                }
                let encodedPath = encodedComponents.joined(separator: "/")
                let publicUrlString = "\(Config.supabaseURL.absoluteString)/storage/v1/object/public/memoji-images/\(encodedPath)"
                
                guard let publicUrl = URL(string: publicUrlString) else {
                    print("[WebService] fetchImage: ❌ Failed to construct URL for memoji path: \(imageFileHash)")
                    throw NetworkError.badUrl
                }
                fileLocation = FileLocation.url(publicUrl)
            } else {
                // For product images, use Supabase download API
                fileLocation = FileLocation.supabase(SupabaseFile(bucket: "productimages", name: imageFileHash))
            }
            
        case .scanImagePath(let storagePath):
            // User-uploaded scan images are stored in the "scan-images" bucket
            fileLocation = FileLocation.supabase(SupabaseFile(bucket: "scan-images", name: storagePath))
        }

        let data: Data
        switch imageSize {
        case .small:
            data = try await smallImageStore.fetchFile(fileLocation: fileLocation)
        case .medium:
            data = try await mediumImageStore.fetchFile(fileLocation: fileLocation)
        case .large:
            data = try await largeImageStore.fetchFile(fileLocation: fileLocation)
        }
        
        // CRITICAL: UIImage(data:) must be called on main thread - UIImage operations are not thread-safe
        let image = await MainActor.run {
            UIImage(data: data)
        }
        
        guard let validImage = image else {
            throw NetworkError.decodingError
        }
        
        return validImage
    }

    func streamUnifiedAnalysis(
        input: UnifiedAnalysisInput,
        clientActivityId: String,
        userPreferenceText: String,
        onProduct: @escaping (DTO.Product) -> Void,
        onAnalysis: @escaping ([DTO.IngredientRecommendation]) -> Void,
        onError: @escaping (UnifiedAnalysisStreamError) -> Void
    ) async throws {

        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        var productReceivedTime: TimeInterval?
        var analysisReceivedTime: TimeInterval?
        var hasReportedError = false

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        var requestBuilder = SupabaseRequestBuilder(endpoint: .ingredicheck_analyze_stream)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "userPreferenceText", value: userPreferenceText)

        var analyticsProperties: [String: Any] = [
            "request_id": requestId,
            "client_activity_id": clientActivityId,
            "preference_length": userPreferenceText.count,
            "has_preferences": !userPreferenceText.isEmpty && userPreferenceText.lowercased() != "none"
        ]

        switch input {
        case .barcode(let barcode):
            requestBuilder = requestBuilder.setFormData(name: "barcode", value: barcode)
            analyticsProperties["input_type"] = "barcode"
            analyticsProperties["barcode"] = barcode
        case .productImages:
            // DEPRECATED: productImages case no longer supported
            // Use the new Scan API (submitScanImage + getScan) for photo scans instead
            throw NetworkError.invalidResponse(400)  // Bad request - method deprecated
        }

        var request = requestBuilder.build()
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120

        PostHogSDK.shared.capture("Unified Analysis Stream Started", properties: analyticsProperties)
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(-1)
        }

        guard httpResponse.statusCode == 200 else {
            analyticsProperties["status_code"] = httpResponse.statusCode
            PostHogSDK.shared.capture("Unified Analysis Stream Failed - HTTP", properties: analyticsProperties)

            let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            let streamError = UnifiedAnalysisStreamError(message: message, statusCode: httpResponse.statusCode)
            await MainActor.run {
                onError(streamError)
            }

            if httpResponse.statusCode == 404 {
                throw NetworkError.notFound(message)
            } else {
                throw NetworkError.invalidResponse(httpResponse.statusCode)
            }
        }

        var buffer = ""
        var shouldTerminate = false
        let doubleNewline = "\n\n"
        let carriageReturnNewline = "\r\n\r\n"

        func decodePayload<T: Decodable>(_ payload: String, as type: T.Type) throws -> T {
            let decoder = JSONDecoder()

                if let data = payload.data(using: .utf8) {
                    if let decoded = try? decoder.decode(T.self, from: data) {
                        return decoded
                    }

                    if let nestedString = try? decoder.decode(String.self, from: data) {
                        if let nestedData = nestedString.data(using: .utf8),
                           let decoded = try? decoder.decode(T.self, from: nestedData) {
                            return decoded
                        }
                    }
                }

            throw NetworkError.decodingError
        }

        struct SSEWrapper: Decodable {
            let event: String
            let data: String
        }

        struct SSEErrorWrapper: Decodable {
            let message: String
            let status: Int?
            let statusCode: Int?
            let details: String?
        }

        func processEvent(_ rawEvent: String) async {
            let trimmedEvent = rawEvent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedEvent.isEmpty else { return }

            var eventType: String?
            var dataLines: [String] = []

            trimmedEvent.split(whereSeparator: \.isNewline).forEach { line in
                if line.hasPrefix("event:") {
                    eventType = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    dataLines.append(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
                }
            }

            var payloadString = dataLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            if (eventType == nil || eventType == "message"), !payloadString.isEmpty,
               let payloadData = payloadString.data(using: .utf8) {
                if let wrapper = try? JSONDecoder().decode(SSEWrapper.self, from: payloadData) {
                    eventType = wrapper.event
                    payloadString = wrapper.data
                } else if let jsonObject = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                          let wrappedEvent = jsonObject["event"] as? String {
                    eventType = wrappedEvent
                    if let nested = jsonObject["data"] as? String {
                        payloadString = nested
                    } else if let nestedJson = jsonObject["data"],
                              JSONSerialization.isValidJSONObject(nestedJson),
                              let nestedData = try? JSONSerialization.data(withJSONObject: nestedJson),
                              let nestedString = String(data: nestedData, encoding: .utf8) {
                        payloadString = nestedString
                    }
                }
            }

            guard let resolvedEventType = eventType else { return }

            switch resolvedEventType {
            case "scan":
                guard !payloadString.isEmpty else { return }
                
                // Define payload structure locally to match the partial/progressive SSE response
                struct ScanStreamPayload: Decodable {
                    let id: String
                    let state: String
                    let barcode: String?
                    let product_info: DTO.ScanProductInfo?
                    let analysis_result: DTO.ScanAnalysisResult?
                    let error: String?
                    
                    func toProduct() -> DTO.Product? {
                        guard let info = product_info else { return nil }
                        
                        // Map images from ScanProductInfo to ImageLocationInfo
                        let mappedImages = info.images?.compactMap { imgInfo -> DTO.ImageLocationInfo? in
                            guard let urlString = imgInfo.url, let url = URL(string: urlString) else { return nil }
                            return .url(url)
                        } ?? []
                        
                        return DTO.Product(
                            barcode: barcode,
                            brand: info.brand,
                            name: info.name ?? "Scanning...",
                            ingredients: info.ingredients,
                            images: mappedImages,
                            claims: info.claims
                        )
                    }
                }

                do {
                    let scanPayload: ScanStreamPayload = try decodePayload(payloadString, as: ScanStreamPayload.self)
                    
                    switch scanPayload.state {
                    case "fetching_product_info":
                        // Initial state, maybe just log or update generic feedback
                        // The UI might use "Scanning..." based on analyzing state
                        break
                        
                    case "analyzing":
                        // We have product info but no analysis yet
                        if let product = scanPayload.toProduct() {
                            productReceivedTime = Date().timeIntervalSince1970
                            
                            var productProps = analyticsProperties
                            productProps["product_name"] = product.name ?? "Unknown"
                            productProps["state"] = "analyzing"
                            PostHogSDK.shared.capture("Unified Analysis Stream Product", properties: productProps)
                            
                            await MainActor.run {
                                onProduct(product)
                            }
                        }
                        
                    case "done":
                        // Final state with analysis
                        if let analysis = scanPayload.analysis_result {
                            let recommendations = analysis.toIngredientRecommendations()
                            
                            analysisReceivedTime = Date().timeIntervalSince1970
                            
                            var analysisProps = analyticsProperties
                            analysisProps["recommendations_count"] = recommendations.count
                            analysisProps["state"] = "done"
                            PostHogSDK.shared.capture("Unified Analysis Stream Done", properties: analysisProps)
                            
                            // Send product update again (to ensure match status is updated with analysis)
                            if let product = scanPayload.toProduct() {
                                await MainActor.run {
                                    onProduct(product)
                                }
                            }
                            
                            await MainActor.run {
                                onAnalysis(recommendations)
                            }
                            
                            shouldTerminate = true
                        }
                        
                    case "error":
                        hasReportedError = true
                        let errorMessage = scanPayload.error ?? "Unknown scan error"
                        
                        var errorProps = analyticsProperties
                        errorProps["error_message"] = errorMessage
                        PostHogSDK.shared.capture("Unified Analysis Stream Error Event", properties: errorProps)
                        
                        await MainActor.run {
                            onError(UnifiedAnalysisStreamError(message: errorMessage, statusCode: nil))
                        }
                        shouldTerminate = true
                        
                    default:
                        break
                    }
                    
                } catch {
                    var errorProps = analyticsProperties
                    errorProps["decode_stage"] = "scan"
                    errorProps["raw_payload"] = payloadString
                    PostHogSDK.shared.capture("Unified Analysis Stream Decode Error", properties: errorProps)
                    print("[SSE] Failed to decode scan payload: \(error)")
                }

            case "product":
                guard !payloadString.isEmpty else { return }
                do {
                    let product: DTO.Product = try decodePayload(payloadString, as: DTO.Product.self)
                    productReceivedTime = Date().timeIntervalSince1970
                    let productLatency = (productReceivedTime! - startTime) * 1000

                    var productProps = analyticsProperties
                    productProps["product_latency_ms"] = productLatency
                    productProps["product_name"] = product.name ?? "Unknown"

                    PostHogSDK.shared.capture("Unified Analysis Stream Product", properties: productProps)

                    await MainActor.run {
                        onProduct(product)
                    }
                } catch {
                    var errorProps = analyticsProperties
                    errorProps["decode_stage"] = "product"
                    errorProps["raw_payload"] = payloadString
                    PostHogSDK.shared.capture("Unified Analysis Stream Decode Error", properties: errorProps)
                }
            case "analysis":
                guard !payloadString.isEmpty else { return }
                do {
                    let recommendations: [DTO.IngredientRecommendation] = try decodePayload(payloadString, as: [DTO.IngredientRecommendation].self)
                    analysisReceivedTime = Date().timeIntervalSince1970
                    let totalLatency = (analysisReceivedTime! - startTime) * 1000
                    let analysisLatency = productReceivedTime != nil ? (analysisReceivedTime! - productReceivedTime!) * 1000 : totalLatency

                    var analysisProps = analyticsProperties
                    analysisProps["analysis_latency_ms"] = analysisLatency
                    analysisProps["total_latency_ms"] = totalLatency
                    if let productReceivedTime {
                        analysisProps["product_latency_ms"] = (productReceivedTime - startTime) * 1000
                    }
                    analysisProps["recommendations_count"] = recommendations.count

                    PostHogSDK.shared.capture("Unified Analysis Stream Recommendations", properties: analysisProps)

                    await MainActor.run {
                        onAnalysis(recommendations)
                    }
                } catch {
                    var errorProps = analyticsProperties
                    errorProps["decode_stage"] = "analysis"
                    errorProps["raw_payload"] = payloadString
                    PostHogSDK.shared.capture("Unified Analysis Stream Decode Error", properties: errorProps)
                }
            case "error":
                guard !payloadString.isEmpty else { return }
                hasReportedError = true
                var errorMessage = "Server error occurred."
                var statusCode: Int?

                if let errorData = payloadString.data(using: .utf8) {
                    if let wrapper = try? JSONDecoder().decode(SSEErrorWrapper.self, from: errorData) {
                        errorMessage = wrapper.message
                        statusCode = wrapper.statusCode ?? wrapper.status
                    } else if let jsonObject = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any] {
                        if let message = jsonObject["message"] as? String {
                            errorMessage = message
                        }
                        if let status = jsonObject["statusCode"] as? Int {
                            statusCode = status
                        } else if let status = jsonObject["status"] as? Int {
                            statusCode = status
                        }
                    } else if let decodedString = try? JSONDecoder().decode(String.self, from: errorData) {
                        errorMessage = decodedString
                    }
                }

                var errorProps = analyticsProperties
                errorProps["error_message"] = errorMessage
                errorProps["error_status"] = statusCode ?? 0
                errorProps["elapsed_ms"] = (Date().timeIntervalSince1970 - startTime) * 1000

                PostHogSDK.shared.capture("Unified Analysis Stream Error Event", properties: errorProps)

                await MainActor.run {
                    onError(UnifiedAnalysisStreamError(message: errorMessage, statusCode: statusCode))
                }

                shouldTerminate = true
            default:
                break
            }
        }

        do {
            for try await byte in asyncBytes {
                if shouldTerminate {
                    break
                }

                let scalar = UnicodeScalar(byte)
                buffer.append(Character(scalar))

                while true {
                    if let range = buffer.range(of: doubleNewline) {
                        let eventString = String(buffer[..<range.lowerBound])
                        buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                        await processEvent(eventString)
                    } else if let range = buffer.range(of: carriageReturnNewline) {
                        let eventString = String(buffer[..<range.lowerBound])
                        buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                        await processEvent(eventString)
                    } else {
                        break
                    }

                    if shouldTerminate {
                        break
                    }
                }
            }

            if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await processEvent(buffer)
            }
        } catch {
            if !hasReportedError && !(error is CancellationError) {
                var errorProps = analyticsProperties
                errorProps["error"] = error.localizedDescription
                errorProps["elapsed_ms"] = (Date().timeIntervalSince1970 - startTime) * 1000
                PostHogSDK.shared.capture("Unified Analysis Stream Network Error", properties: errorProps)

                await MainActor.run {
                    onError(UnifiedAnalysisStreamError(message: error.localizedDescription, statusCode: nil))
                }
            }

            throw error
        }

        if !hasReportedError {
            var completionProps = analyticsProperties
            completionProps["elapsed_ms"] = (Date().timeIntervalSince1970 - startTime) * 1000
            completionProps["product_received"] = productReceivedTime != nil
            completionProps["analysis_received"] = analysisReceivedTime != nil

            PostHogSDK.shared.capture("Unified Analysis Stream Completed", properties: completionProps)
        }
    }

    // MARK: - Scan API
    
    func streamBarcodeScan(
        barcode: String,
        onProductInfo: @escaping (DTO.ScanProductInfo, String, String, [DTO.ScanImage]) -> Void,  // (productInfo, scanId, product_info_source, images)
        onAnalysis: @escaping (DTO.ScanAnalysisResult) -> Void,
        onError: @escaping (ScanStreamError, String?) -> Void  // (error, scanId)
    ) async throws {
        
        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        var scanId: String?
        var hasReportedError = false
        
        print("[BARCODE_SCAN] 🔵 Starting barcode scan - barcode: \(barcode), request_id: \(requestId)")
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            print("[BARCODE_SCAN] ❌ Auth error - no access token")
            throw NetworkError.authError
        }
        
        let requestBody = try JSONEncoder().encode(["barcode": barcode])
        let endpoint = Config.flyDevAPIBase + SafeEatsEndpoint.scan_barcode.rawValue
        
        var request = SupabaseRequestBuilder(endpoint: .scan_barcode)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setJsonBody(to: requestBody)
            .build()
        
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        
        print("[BARCODE_SCAN] 📡 API Call: POST \(endpoint)")
        print("[BARCODE_SCAN] 📡 Request body: barcode=\(barcode)")
        
        PostHogSDK.shared.capture("Barcode Scan Started", properties: [
            "request_id": requestId,
            "barcode": barcode
        ])
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[BARCODE_SCAN] ❌ HTTP Error - Status: \(statusCode)")
            PostHogSDK.shared.capture("Barcode Scan Failed - HTTP", properties: [
                "request_id": requestId,
                "status_code": statusCode
            ])
            throw NetworkError.invalidResponse(statusCode)
        }
        
        print("[BARCODE_SCAN] ✅ Connected to SSE stream - Status: 200, starting to receive events...")
        print("[BARCODE_SCAN] ⏳ Polling: NO (using Server-Sent Events stream)")
        
        var buffer = ""
        let doubleNewline = "\n\n"
        
        func processEvent(_ rawEvent: String) async {
            let trimmed = rawEvent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            var eventType: String?
            var dataLines: [String] = []
            
            trimmed.split(whereSeparator: \.isNewline).forEach { line in
                if line.hasPrefix("event:") {
                    eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                }
            }
            
            let payloadString = dataLines.joined(separator: "\n")
            guard let resolvedEventType = eventType,
                  let payloadData = payloadString.data(using: .utf8) else { return }
            
            switch resolvedEventType {
            case "product_info":
                // Log raw payload before decoding
                print("[BARCODE_SCAN] 📄 Raw SSE Event (product_info):")
                print(payloadString)
                
                do {
                    let event = try JSONDecoder().decode(DTO.ScanProductInfoEvent.self, from: payloadData)
                    scanId = event.scan_id
                    
                    let latency = (Date().timeIntervalSince1970 - startTime) * 1000
                    print("[BARCODE_SCAN] 📦 Event: product_info - scan_id: \(event.scan_id), source: \(event.product_info_source), latency: \(Int(latency))ms")
                    
                    PostHogSDK.shared.capture("Barcode Scan Product Info", properties: [
                        "request_id": requestId,
                        "scan_id": event.scan_id,
                        "source": event.product_info_source,
                        "latency_ms": latency
                    ])
                    
                    await MainActor.run {
                        // Pass full event data to callback
                        onProductInfo(event.product_info, event.scan_id, event.product_info_source, event.images)
                    }
                } catch {
                    print("[BARCODE_SCAN] ❌ Failed to decode product_info: \(error)")
                    // Log the raw payload for debugging
                    if let payloadString = String(data: payloadData, encoding: .utf8) {
                        print("[BARCODE_SCAN] 📄 Raw product_info payload: \(payloadString.prefix(1000))")
                    }
                }
                
            case "analysis":
                // Log raw payload before decoding
                print("[BARCODE_SCAN] 📄 Raw SSE Event (analysis):")
                print(payloadString)
                
                do {
                    let event = try JSONDecoder().decode(DTO.ScanAnalysisEvent.self, from: payloadData)
                    
                    let latency = (Date().timeIntervalSince1970 - startTime) * 1000
                    print("[BARCODE_SCAN] ✅ Event: analysis - scan_id: \(scanId ?? "unknown"), status: \(event.analysis_status), latency: \(Int(latency))ms")
                    
                    if let result = event.analysis_result {
                        // Log raw ingredient_analysis data including members_affected
                        print("[BARCODE_SCAN] 📊 Raw analysis_result - ingredient_analysis count: \(result.ingredient_analysis.count)")
                        for (index, analysis) in result.ingredient_analysis.enumerated() {
                            print("[BARCODE_SCAN] 📊 ingredient_analysis[\(index)]: ingredient=\(analysis.ingredient), match=\(analysis.match), members_affected=\(analysis.members_affected)")
                        }
                        
                        print("[BARCODE_SCAN] 🎯 Scan complete - no polling needed (SSE stream)")
                        
                        PostHogSDK.shared.capture("Barcode Scan Analysis", properties: [
                            "request_id": requestId,
                            "scan_id": scanId ?? "unknown"
                        ])
                        
                        await MainActor.run {
                            onAnalysis(result)
                        }
                    } else {
                        print("[BARCODE_SCAN] ⚠️ Analysis event received but analysis_result is nil - status: \(event.analysis_status)")
                    }
                } catch {
                    print("[BARCODE_SCAN] ❌ Failed to decode analysis: \(error)")
                    // Log the raw payload for debugging
                    if let payloadString = String(data: payloadData, encoding: .utf8) {
                        print("[BARCODE_SCAN] 📄 Raw payload: \(payloadString.prefix(500))")
                    }
                }
                
            case "error":
                // Log raw payload before processing
                print("[BARCODE_SCAN] 📄 Raw SSE Event (error):")
                print(payloadString)
                
                hasReportedError = true
                var errorMessage = "Product not found"
                
                if let jsonObject = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                    if let id = jsonObject["scan_id"] as? String {
                        scanId = id
                    }
                    if let msg = jsonObject["error"] as? String {
                        errorMessage = msg
                    }
                }
                
                print("[BARCODE_SCAN] ❌ Event: error - scan_id: \(scanId ?? "unknown"), error: \(errorMessage)")
                
                PostHogSDK.shared.capture("Barcode Scan Error", properties: [
                    "request_id": requestId,
                    "scan_id": scanId ?? "unknown",
                    "error": errorMessage
                ])
                
                await MainActor.run {
                    onError(ScanStreamError(message: errorMessage, statusCode: nil), scanId)
                }
                
            case "done":
                print("[BARCODE_SCAN] ✅ Event: done - stream completed")
                break
                
            default:
                print("[BARCODE_SCAN] ⚠️ Unknown event type: \(resolvedEventType ?? "nil")")
                break
            }
        }
        
        do {
            for try await byte in asyncBytes {
                let scalar = UnicodeScalar(byte)
                buffer.append(Character(scalar))
                
                while let range = buffer.range(of: doubleNewline) {
                    let eventString = String(buffer[..<range.lowerBound])
                    buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                    await processEvent(eventString)
                }
            }
            
            if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await processEvent(buffer)
            }
        } catch {
            if !hasReportedError && !(error is CancellationError) {
                print("[BARCODE_SCAN] ❌ Stream error: \(error.localizedDescription)")
                await MainActor.run {
                    onError(ScanStreamError(message: error.localizedDescription, statusCode: nil), scanId)
                }
            }
            throw error
        }
        
        let totalLatency = (Date().timeIntervalSince1970 - startTime) * 1000
        print("[BARCODE_SCAN] ✅ Barcode scan completed - total latency: \(Int(totalLatency))ms")
    }
    
    func submitScanImage(
        scanId: String,
        imageData: Data
    ) async throws -> DTO.SubmitImageResponse {
        
        let imageSizeKB = imageData.count / 1024
        print("[PHOTO_SCAN] 📸 Submitting image - scan_id: \(scanId), image_size: \(imageSizeKB)KB")
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            print("[PHOTO_SCAN] ❌ Auth error - no access token")
            throw NetworkError.authError
        }
        
        let endpoint = Config.flyDevAPIBase + String(format: SafeEatsEndpoint.scan_image.rawValue, scanId)
        let request = SupabaseRequestBuilder(endpoint: .scan_image, itemId: scanId)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "image", value: imageData, contentType: "image/jpeg")
            .build()
        
        print("[PHOTO_SCAN] 📡 API Call: POST \(endpoint)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        switch httpResponse.statusCode {
        case 200:
            let submitResponse = try JSONDecoder().decode(DTO.SubmitImageResponse.self, from: data)
            print("[PHOTO_SCAN] ✅ Image submitted successfully - scan_id: \(scanId), queued: \(submitResponse.queued), queue_position: \(submitResponse.queue_position)")
            return submitResponse
        case 401:
            print("[PHOTO_SCAN] ❌ Status 401 - Unauthorized")
            throw NetworkError.authError
        case 403:
            print("[PHOTO_SCAN] ❌ Status 403 - Scan belongs to another user")
            throw NetworkError.notFound("Scan belongs to another user")
        case 413:
            print("[PHOTO_SCAN] ❌ Status 413 - Image too large (>10MB)")
            throw NetworkError.invalidResponse(413)  // Image too large (>10MB)
        case 400:
            print("[PHOTO_SCAN] ❌ Status 400 - Max images reached (20)")
            throw NetworkError.invalidResponse(400)  // Max images reached (20)
        case 502, 503, 504:
            // Server-side errors - gateway/proxy/upstream issues
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("[PHOTO_SCAN] ❌ Status \(httpResponse.statusCode) - Server error (likely server-side issue)")
            print("[PHOTO_SCAN] 📄 Response body: \(responseBody.prefix(500))")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        default:
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("[PHOTO_SCAN] ❌ Status \(httpResponse.statusCode) - Unexpected error")
            print("[PHOTO_SCAN] 📄 Response body: \(responseBody.prefix(500))")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func reanalyzeScan(scanId: String) async throws -> DTO.Scan {
        print("[REANALYZE] 🔄 Reanalyzing scan - scan_id: \(scanId)")
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            print("[REANALYZE] ❌ Auth error - no access token")
            throw NetworkError.authError
        }
        
        // Use endpoint construction logic directly or update SupabaseRequestBuilder to handle it
        // Since we added .scan_reanalyze to SupabaseRequestBuilder, we can use it.
        // Note: The formatted URL string logic in SupabaseRequestBuilder might need double check 
        // if it handles single parameter correctly for scan/%@/reanalyze
        // endpoint.rawValue is scan/%@/reanalyze. formatting with scanId should work.
        
        let endpoint = Config.flyDevAPIBase + String(format: SafeEatsEndpoint.scan_reanalyze.rawValue, scanId)
        let request = SupabaseRequestBuilder(endpoint: .scan_reanalyze, itemId: scanId)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .build()
        
        print("[REANALYZE] 📡 API Call: POST \(endpoint)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("[REANALYZE] ❌ HTTP Error - Status: \(httpResponse.statusCode)")
            print("[REANALYZE] 📄 Response body: \(responseBody)")
            
            if httpResponse.statusCode == 400 {
                // Cannot reanalyze (e.g. no ingredients)
                throw NetworkError.invalidResponse(400)
            } else if httpResponse.statusCode == 404 {
                throw NetworkError.notFound("Scan not found")
            } else {
                throw NetworkError.invalidResponse(httpResponse.statusCode)
            }
        }
        
        do {
            let scan = try JSONDecoder().decode(DTO.Scan.self, from: data)
            print("[REANALYZE] ✅ Reanalysis complete - scan_id: \(scan.id)")
            return scan
        } catch {
            print("[REANALYZE] ❌ Failed to decode reanalysis response: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    func getScan(scanId: String) async throws -> DTO.Scan {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            print("[PHOTO_SCAN] ❌ Auth error - no access token for polling")
            throw NetworkError.authError
        }
        
        let endpoint = Config.supabaseFunctionsURLBase + String(format: SafeEatsEndpoint.scan_get.rawValue, scanId)
        let request = SupabaseRequestBuilder(endpoint: .scan_get, itemId: scanId)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()
        
        print("[PHOTO_SCAN] 🔄 Polling: GET \(endpoint)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        switch httpResponse.statusCode {
        case 200:
            // Log raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("[PHOTO_SCAN] 📄 Raw response: \(rawResponse)")
            }
            
            do {
                let scan = try JSONDecoder().decode(DTO.Scan.self, from: data)
            print("[PHOTO_SCAN] ✅ Poll response - scan_id: \(scanId), state: \(scan.state)")
            
                // Log raw ingredient_analysis data including members_affected if available
                if let analysisResult = scan.analysis_result {
                    print("[PHOTO_SCAN] 📊 Raw analysis_result - ingredient_analysis count: \(analysisResult.ingredient_analysis.count)")
                    for (index, analysis) in analysisResult.ingredient_analysis.enumerated() {
                        print("[PHOTO_SCAN] 📊 ingredient_analysis[\(index)]: ingredient=\(analysis.ingredient), match=\(analysis.match), members_affected=\(analysis.members_affected)")
                    }
                }
                
                return scan
            } catch let error {
                // Log detailed decoding error
                print("[PHOTO_SCAN] ❌ Failed to decode Scan: \(error)")
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("[PHOTO_SCAN] 📄 Raw response that failed to decode: \(rawResponse)")
                }
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("[PHOTO_SCAN] ❌ Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("[PHOTO_SCAN] ❌ Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(let type, let context):
                        print("[PHOTO_SCAN] ❌ Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        print("[PHOTO_SCAN] ❌ Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), \(context.debugDescription)")
                    @unknown default:
                        print("[PHOTO_SCAN] ❌ Unknown decoding error: \(decodingError)")
                    }
                }
                throw error
            }
        case 401:
            print("[PHOTO_SCAN] ❌ Poll Status 401 - Unauthorized")
            throw NetworkError.authError
        case 403:
            print("[PHOTO_SCAN] ❌ Poll Status 403 - Scan belongs to another user")
            throw NetworkError.notFound("Scan belongs to another user")
        case 404:
            print("[PHOTO_SCAN] ❌ Poll Status 404 - Scan not found")
            throw NetworkError.notFound("Scan not found")
        default:
            print("[PHOTO_SCAN] ❌ Poll Status \(httpResponse.statusCode) - Unexpected error")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func fetchScanHistory(
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> DTO.ScanHistoryResponse {
        
        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        let request = SupabaseRequestBuilder(endpoint: .scan_history)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .setQueryItems(queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ])
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        // Log raw response
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("[SCAN_HISTORY] 📄 Raw API Response:")
            print(rawResponse)
        } else {
            print("[SCAN_HISTORY] ⚠️ Could not convert response data to string")
        }
        
        guard httpResponse.statusCode == 200 else {
            PostHogSDK.shared.capture("Scan History Fetch Failed", properties: [
                "request_id": requestId,
                "status_code": httpResponse.statusCode,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        do {
            let historyResponse = try JSONDecoder().decode(DTO.ScanHistoryResponse.self, from: data)
            
            PostHogSDK.shared.capture("Scan History Fetch Successful", properties: [
                "request_id": requestId,
                "scan_count": historyResponse.scans.count,
                "total": historyResponse.total,
                "has_more": historyResponse.has_more,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])
            
            return historyResponse
        } catch {
            print("Failed to decode ScanHistoryResponse: \(error)")
            
            PostHogSDK.shared.capture("Scan History Decode Error", properties: [
                "request_id": requestId,
                "error": error.localizedDescription,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])
            
            throw NetworkError.decodingError
        }
    }

    func submitFeedback(
        clientActivityId: String,
        feedbackData: FeedbackData
    ) async throws {

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        var feedbackDataDto = DTO.FeedbackData()
        feedbackDataDto.rating = feedbackData.rating
        feedbackDataDto.reasons =
            feedbackData.reasons.isEmpty
            ? nil
            : Array(feedbackData.reasons).map { reason in reason.rawValue }
        feedbackDataDto.note =
            feedbackData.note.isEmpty
            ? nil
            : feedbackData.note
        feedbackDataDto.images =
            feedbackData.images.isEmpty
            ? nil
            : try await feedbackData.images.asyncMap { productImage in
                // Upload image and get hash
                let imageFileHash = try await uploadImage(image: productImage.image)
                // For feedback, we don't need OCR text or barcode
                return DTO.ImageInfo(
                    imageFileHash: imageFileHash,
                    imageOCRText: "",  // Not needed for feedback
                    barcode: nil  // Not needed for feedback
                )
            }

        let feedbackDataJson = try JSONEncoder().encode(feedbackDataDto)
        let feedbackDataJsonString = String(data: feedbackDataJson, encoding: .utf8)!

        let request = SupabaseRequestBuilder(endpoint: .feedback)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "feedback", value: feedbackDataJsonString)
            .build()

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 201 else {
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }

    func fetchHistory(searchText: String? = nil) async throws -> [DTO.HistoryItem] {

        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        var requestBuilder = SupabaseRequestBuilder(endpoint: .history)
            .setAuthorization(with: token)
            .setMethod(to: "GET")

        if let searchText {
            requestBuilder =
                requestBuilder
                    .setQueryItems(queryItems: [
                        URLQueryItem(name: "searchText", value: searchText)
                    ])
        }

        let request = requestBuilder.build()

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            PostHogSDK.shared.capture("History Fetch Failed", properties: [
                "request_id": requestId,
                "has_search_text": searchText != nil,
                "search_length": searchText?.count ?? 0,
                "status_code": httpResponse.statusCode,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        do {
            let history = try JSONDecoder().decode([DTO.HistoryItem].self, from: data)

            PostHogSDK.shared.capture("History Fetch Successful", properties: [
                "request_id": requestId,
                "has_search_text": searchText != nil,
                "search_length": searchText?.count ?? 0,
                "history_count": history.count,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            return history
        } catch {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("Failed to decode History object: \(error)")
            print(responseText)

            PostHogSDK.shared.capture("History Fetch Decode Error", properties: [
                "request_id": requestId,
                "has_search_text": searchText != nil,
                "search_length": searchText?.count ?? 0,
                "error": error.localizedDescription,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.decodingError
        }
    }

    func uploadImage(image: UIImage) async throws -> String {
        print("[WebService] uploadImage: Before pngData() - Thread.isMainThread=\(Thread.isMainThread)")
        // CRITICAL: pngData() must be called on main thread - UIImage operations are not thread-safe
        let imageData = await MainActor.run {
            let isMainThread = Thread.isMainThread
            print("[WebService] uploadImage: Inside MainActor.run - Thread.isMainThread=\(isMainThread)")
            let data = image.pngData()!
            print("[WebService] uploadImage: pngData() completed - data size=\(data.count) bytes")
            return data
        }
        print("[WebService] uploadImage: After MainActor.run - Thread.isMainThread=\(Thread.isMainThread)")
        let imageFileName = SHA256.hash(data: imageData).compactMap { String(format: "%02x", $0) }.joined()
        
        print("[WebService] uploadImage: Uploading image to storage with key=\(imageFileName)")
        
        do {
            try await supabaseClient.storage.from("productimages").upload(
                path: imageFileName,
                file: imageData,
                options: FileOptions(contentType: "image/png")
            )
            print("[WebService] uploadImage: ✅ Upload succeeded for key=\(imageFileName)")
        } catch {
            let message = String(describing: error)
            // Supabase storage returns "The resource already exists" when the same
            // object key is uploaded again. In our case the key is a SHA256 hash
            // of the image bytes, so if the content is identical we can safely
            // treat this as a success and reuse the existing object.
            if message.contains("resource already exists") {
                print("[WebService] uploadImage: ℹ️ Resource already exists for key=\(imageFileName), reusing existing file")
            } else {
                print("[WebService] uploadImage: ❌ Upload failed for key=\(imageFileName): \(error.localizedDescription)")
                throw error
            }
        }
    
        return imageFileName
    }

    func deleteImages(imageFileNames: [String]) async throws {
        _ = try await supabaseClient.storage.from("productimages").remove(paths: imageFileNames)
    }

    /// Toggles favorite status for a scan using the v2 API
    /// POST /v2/scan/{scan_id}/favorite
    /// Returns the new `is_favorited` state
    func toggleFavorite(scanId: String) async throws -> Bool {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            print("[FAVORITE] ❌ Auth error - no access token")
            throw NetworkError.authError
        }
        
        let endpoint = Config.supabaseFunctionsURLBase + String(format: SafeEatsEndpoint.scan_favorite.rawValue, scanId)
        let request = SupabaseRequestBuilder(endpoint: .scan_favorite, itemId: scanId)
            .setAuthorization(with: token)
            .setMethod(to: "PATCH")
            .build()
        
        print("[FAVORITE] 📡 API Call: POST \(endpoint)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        switch httpResponse.statusCode {
        case 200:
            // Parse response to get is_favorited value
            struct FavoriteResponse: Codable {
                let is_favorited: Bool
            }
            
            do {
                let favoriteResponse = try JSONDecoder().decode(FavoriteResponse.self, from: data)
                print("[FAVORITE] ✅ Toggle successful - scanId: \(scanId), is_favorited: \(favoriteResponse.is_favorited)")
                return favoriteResponse.is_favorited
            } catch {
                print("[FAVORITE] ❌ Failed to decode response: \(error)")
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("[FAVORITE] 📄 Raw response: \(rawResponse)")
                }
                throw NetworkError.decodingError
            }
        case 401:
            print("[FAVORITE] ❌ Status 401 - Unauthorized")
            throw NetworkError.authError
        case 404:
            print("[FAVORITE] ❌ Status 404 - Scan not found")
            throw NetworkError.notFound("Scan not found")
        default:
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("[FAVORITE] ❌ Status \(httpResponse.statusCode) - Unexpected error")
            print("[FAVORITE] 📄 Response body: \(responseBody.prefix(500))")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    // MARK: - Legacy Favorite Methods (deprecated, use toggleFavorite instead)
    
    @available(*, deprecated, message: "Use toggleFavorite(scanId:) instead")
    func addToFavorites(clientActivityId: String) async throws {
        // For backward compatibility, call toggleFavorite
        // Note: This may toggle OFF if already favorited
        _ = try await toggleFavorite(scanId: clientActivityId)
    }
    
    @available(*, deprecated, message: "Use toggleFavorite(scanId:) instead")
    func removeFromFavorites(clientActivityId: String) async throws {
        // For backward compatibility, call toggleFavorite
        // Note: This may toggle ON if not favorited
        _ = try await toggleFavorite(scanId: clientActivityId)
    }
    
    func getFavorites(searchText: String? = nil) async throws -> [DTO.ListItem] {

        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let listId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!.uuidString

        var requestBuilder = SupabaseRequestBuilder(endpoint: .list_items, itemId: listId)
            .setAuthorization(with: token)
            .setMethod(to: "GET")

        if let searchText {
            requestBuilder =
                requestBuilder
                    .setQueryItems(queryItems: [
                        URLQueryItem(name: "searchText", value: searchText)
                    ])
        }

        let request = requestBuilder.build()

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")

            PostHogSDK.shared.capture("Favorites Fetch Failed", properties: [
                "request_id": requestId,
                "has_search_text": searchText != nil,
                "search_length": searchText?.count ?? 0,
                "status_code": httpResponse.statusCode,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        do {
            let listItems = try JSONDecoder().decode([DTO.ListItem].self, from: data)

            PostHogSDK.shared.capture("Favorites Fetch Successful", properties: [
                "request_id": requestId,
                "has_search_text": searchText != nil,
                "search_length": searchText?.count ?? 0,
                "favorites_count": listItems.count,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            return listItems
        } catch {
            print("Failed to decode ListItem array: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)

            PostHogSDK.shared.capture("Favorites Fetch Decode Error", properties: [
                "request_id": requestId,
                "has_search_text": searchText != nil,
                "search_length": searchText?.count ?? 0,
                "error": error.localizedDescription,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.decodingError
        }
    }

    func addOrEditDietaryPreference(
        clientActivityId: String,
        preferenceText: String,
        id: Int?
    ) async throws -> DTO.PreferenceValidationResult {
        
        let requestId: String = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        
        func buildRequest(_ token: String) -> URLRequest {
            if let id {
                PostHogSDK.shared.capture("User Inputed Preference", properties: [
                    "request_id": requestId,
                    "endpoint": SafeEatsEndpoint.preference_lists_default_items.rawValue,
                    "client_activity_id": clientActivityId,
                    "item_id": String(id),
                    "preference_text": preferenceText,
                    "method": "PUT",
                    "start_time": String(startTime)
                ])
                
                return SupabaseRequestBuilder(endpoint: .preference_lists_default_items, itemId: String(id))
                    .setAuthorization(with: token)
                    .setMethod(to: "PUT")
                    .setFormData(name: "clientActivityId", value: clientActivityId)
                    .setFormData(name: "preference", value: preferenceText)
                    .build()
                
            } else {
                PostHogSDK.shared.capture("User Inputed Preference", properties: [
                    "request_id": requestId,
                    "endpoint": SafeEatsEndpoint.preference_lists_default.rawValue,
                    "client_activity_id": clientActivityId,
                    "preference_text": preferenceText,
                    "method": "POST",
                    "start_time": String(startTime)
                ])
                
                return SupabaseRequestBuilder(endpoint: .preference_lists_default)
                    .setAuthorization(with: token)
                    .setMethod(to: "POST")
                    .setFormData(name: "clientActivityId", value: clientActivityId)
                    .setFormData(name: "preference", value: preferenceText)
                    .build()
            }
        }

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request = buildRequest(token)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let httpResponse = response as! HTTPURLResponse

        guard ([200, 201, 204, 422].contains(httpResponse.statusCode)) else {
            
            PostHogSDK.shared.capture("User Input Validation: Bad response from the server", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "preference_text": preferenceText,
                "status_code": httpResponse.statusCode,
                "latency_ms": Date().timeIntervalSince1970 * 1000 - startTime * 1000
            ])
            
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        do {
            PostHogSDK.shared.capture("User Input Validation Successful", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "preference_text": preferenceText,
                "latency_ms": Date().timeIntervalSince1970 * 1000 - startTime * 1000
            ])
            
            return try JSONDecoder().decode(DTO.PreferenceValidationResult.self, from: data)
        } catch {
            PostHogSDK.shared.capture("User Input Validation Error", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "preference_text": preferenceText,
                "latency_ms": Date().timeIntervalSince1970 * 1000 - startTime * 1000,
                "error": error.localizedDescription
            ])
            
            print("Failed to decode PreferenceValidationResult object: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)
            throw NetworkError.decodingError
        }
    }
    
    func getDietaryPreferences() async throws -> [DTO.DietaryPreference] {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request = SupabaseRequestBuilder(endpoint: .preference_lists_default)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode([DTO.DietaryPreference].self, from: data)
        } catch {
            print("Failed to decode [DTO.DietaryPreference] object: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)
            throw NetworkError.decodingError
        }
    }

    func deleteDietaryPreference(
        clientActivityId: String,
        id: Int
    ) async throws -> Void {

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request =
            SupabaseRequestBuilder(endpoint: .preference_lists_default_items, itemId: String(id))
                .setAuthorization(with: token)
                .setMethod(to: "DELETE")
                .setFormData(name: "clientActivityId", value: clientActivityId)
                .build()
        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 204 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func uploadGrandFatheredPreferences(_ preferences: [String]) async throws -> Void {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request =
            SupabaseRequestBuilder(endpoint: .preference_lists_grandfathered)
                .setAuthorization(with: token)
                .setMethod(to: "POST")
                .setJsonBody(
                    to: try! JSONSerialization.data(withJSONObject: preferences, options: [])
                )
                .build()
        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 201 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func deleteUserAccount() async throws -> Void {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request =
            SupabaseRequestBuilder(endpoint: .deleteme)
                .setAuthorization(with: token)
                .setMethod(to: "POST")
                .build()

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 204 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func registerDevice(deviceId: String, platform: String? = nil, osVersion: String? = nil, appVersion: String? = nil, markInternal: Bool? = nil) async throws -> Bool {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        var requestBody: [String: Any] = ["deviceId": deviceId]
        if let platform = platform {
            requestBody["platform"] = platform
        }
        if let osVersion = osVersion {
            requestBody["osVersion"] = osVersion
        }
        if let appVersion = appVersion {
            requestBody["appVersion"] = appVersion
        }
        if let markInternal = markInternal {
            requestBody["markInternal"] = markInternal
        }
        
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let request = SupabaseRequestBuilder(endpoint: .devices_register)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setJsonBody(to: requestBodyData)
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            print("Failed to register device: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        struct RegisterDeviceResponse: Codable {
            let is_internal: Bool
        }
        
        do {
            let response = try JSONDecoder().decode(RegisterDeviceResponse.self, from: data)
            return response.is_internal
        } catch {
            print("Failed to decode register device response: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    func registerDeviceAfterLogin(deviceId: String, completion: @escaping (Bool?) -> Void) {
        Task.detached {
            do {
                let platform = UIDevice.current.systemName.lowercased()
                let osVersion = UIDevice.current.systemVersion
                let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                
                #if targetEnvironment(simulator) || DEBUG
                let markInternal = true
                #else
                let markInternal: Bool? = nil
                #endif
                
                let isInternal = try await self.registerDevice(
                    deviceId: deviceId,
                    platform: platform,
                    osVersion: osVersion,
                    appVersion: appVersion,
                    markInternal: markInternal
                )
                
                completion(isInternal)
            } catch {
                // Silently handle errors - fire-and-forget
                print("Failed to register device after login: \(error)")
                completion(nil)
            }
        }
    }
    
    func markDeviceInternal(deviceId: String) async throws -> (device_id: String, affected_users: Int) {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        let requestBody = ["deviceId": deviceId]
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let request = SupabaseRequestBuilder(endpoint: .devices_mark_internal)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setJsonBody(to: requestBodyData)
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            print("Failed to mark device internal: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        struct MarkInternalResponse: Codable {
            let device_id: String
            let affected_users: Int
        }
        
        do {
            let response = try JSONDecoder().decode(MarkInternalResponse.self, from: data)
            return (response.device_id, response.affected_users)
        } catch {
            print("Failed to decode mark device internal response: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    func isDeviceInternal(deviceId: String) async throws -> Bool {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        let request = SupabaseRequestBuilder(endpoint: .devices_is_internal, itemId: deviceId)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            print("Failed to check device internal status: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        struct IsInternalResponse: Codable {
            let is_internal: Bool
        }
        
        do {
            let response = try JSONDecoder().decode(IsInternalResponse.self, from: data)
            return response.is_internal
        } catch {
            print("Failed to decode is device internal response: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    // MARK: - Network Information Helpers
    
    private func getNetworkType() -> String {
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var networkType: String = "none"
        
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    networkType = "wifi"
                } else if path.usesInterfaceType(.cellular) {
                    networkType = "cellular"
                } else {
                    networkType = "other"
                }
            } else {
                networkType = "none"
            }
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 0.5)
        monitor.cancel()
        
        return networkType
    }
    
    private func getCellularGeneration() -> String {
        let networkInfo = CTTelephonyNetworkInfo()
        
        guard let serviceCurrentRadioAccessTechnology = networkInfo.serviceCurrentRadioAccessTechnology,
              !serviceCurrentRadioAccessTechnology.isEmpty else {
            return "none"
        }
        
        // Get the first available radio access technology
        let radioAccessTechnology = serviceCurrentRadioAccessTechnology.values.first ?? ""
        
        switch radioAccessTechnology {
        case CTRadioAccessTechnologyGPRS,
             CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyCDMA1x:
            return "3g"
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return "3g"
        case CTRadioAccessTechnologyLTE:
            return "4g"
        case CTRadioAccessTechnologyNRNSA,
             CTRadioAccessTechnologyNR:
            return "5g"
        default:
            return "unknown"
        }
    }
    
    private func getCarrier() -> String? {
        let networkInfo = CTTelephonyNetworkInfo()
        
        guard let serviceSubscriberCellularProviders = networkInfo.serviceSubscriberCellularProviders,
              !serviceSubscriberCellularProviders.isEmpty else {
            return nil
        }
        
        // Get the first available carrier
        if let carrier = serviceSubscriberCellularProviders.values.first {
            return carrier.carrierName
        }
        
        return nil
    }
    
    // MARK: - Ping API
    
    func ping() {
        Task.detached { [self] in
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            let deviceModel = UIDevice.current.model
            let networkType = self.getNetworkType()
            let cellularGeneration = networkType == "cellular" ? self.getCellularGeneration() : "none"
            let carrier = networkType == "cellular" ? self.getCarrier() : nil
            
            guard let token = try? await supabaseClient.auth.session.accessToken else {
                return
            }
            
            let request = SupabaseRequestBuilder(endpoint: .ingredicheck_ping)
                .setAuthorization(with: token)
                .setMethod(to: "GET")
                .build()

            do {
                let startTime = Date().timeIntervalSince1970
                let (_, response) = try await URLSession.shared.data(for: request)
                let endTime = Date().timeIntervalSince1970
                let clientLatencyMs = (endTime - startTime) * 1000

                let httpResponse = response as? HTTPURLResponse
                if httpResponse?.statusCode == 204 {
                    var properties: [String: Any] = [
                        "client_latency_ms": clientLatencyMs,
                        "app_version": appVersion,
                        "device_model": deviceModel,
                        "network_type": networkType,
                        "cellular_generation": cellularGeneration
                    ]
                    
                    if let carrier = carrier, !carrier.isEmpty {
                        properties["carrier"] = carrier
                    }
                    
                    print("edge_ping properties: \(properties)")
                    PostHogSDK.shared.capture("edge_ping", properties: properties)
                }
            } catch {
                print("Ping API call failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Food Notes API
    
    // Pretty-print helper for logging JSON responses in the console.
    private func prettyPrintedJSON(from data: Data) -> String {
        guard !data.isEmpty else { return "<empty body>" }
        
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(jsonObject),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        
        // Fallback to raw UTF-8 string if not valid JSON
        return String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
    }
    
    struct FoodNotesResponse {
        let content: [String: Any]
        let version: Int
        let updatedAt: String
    }
    
    struct FoodNotesAllResponse {
        let familyNote: FoodNotesResponse?
        let memberNotes: [String: FoodNotesResponse] // Key is member ID
    }
    
    struct VersionMismatchError: Error {
        let currentNote: FoodNotesResponse
        let expectedVersion: Int
    }
    
    func fetchFoodNotes() async throws -> FoodNotesResponse? {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        print("[WebService] fetchFoodNotes: Starting GET request to /family/food-notes")
        
        let request = SupabaseRequestBuilder(endpoint: .family_food_notes)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("[WebService] fetchFoodNotes: Raw response body (pretty-printed if JSON):\n\(prettyPrintedJSON(from: data))")
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            // 404 means no food notes exist yet, which is fine
            if httpResponse.statusCode == 404 {
                print("[WebService] fetchFoodNotes: No food notes found (404), returning nil")
                return nil
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[WebService] fetchFoodNotes: ❌ Failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        // Backend returns null if no food notes exist (status 200 with null body)
        let responseString = String(data: data, encoding: .utf8) ?? ""
        if responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" || data.isEmpty {
            print("[WebService] fetchFoodNotes: No food notes found (null response), returning nil")
            return nil
        }
        
        // Parse response - include content, version and updatedAt
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = jsonObject["version"] as? Int,
              let updatedAt = jsonObject["updatedAt"] as? String,
              let content = jsonObject["content"] as? [String: Any] else {
            print("[WebService] fetchFoodNotes: ❌ Failed to parse response")
            print("[WebService] fetchFoodNotes: Response body: \(responseString)")
            throw NetworkError.decodingError
        }
        
        print("[WebService] fetchFoodNotes: ✅ Success! Version: \(version), Content keys: \(content.keys.joined(separator: ", "))")
        
        return FoodNotesResponse(content: content, version: version, updatedAt: updatedAt)
    }
    
    func fetchFoodNotesAll() async throws -> FoodNotesAllResponse? {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        print("[WebService] fetchFoodNotesAll: Starting GET request to /family/food-notes/all")
        
        let request = SupabaseRequestBuilder(endpoint: .family_food_notes_all)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("[WebService] fetchFoodNotesAll: Raw response body (pretty-printed if JSON):\n\(prettyPrintedJSON(from: data))")
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            // 404 means no food notes exist yet, which is fine
            if httpResponse.statusCode == 404 {
                print("[WebService] fetchFoodNotesAll: No food notes found (404), returning nil")
                return nil
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[WebService] fetchFoodNotesAll: ❌ Failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        // Backend returns null if no food notes exist (status 200 with null body)
        let responseString = String(data: data, encoding: .utf8) ?? ""
        if responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" || data.isEmpty {
            print("[WebService] fetchFoodNotesAll: No food notes found (null response), returning nil")
            return nil
        }
        
        // Parse response - includes familyNote and memberNotes
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[WebService] fetchFoodNotesAll: ❌ Failed to parse response")
            print("[WebService] fetchFoodNotesAll: Response body: \(responseString)")
            throw NetworkError.decodingError
        }
        
        // Parse familyNote (can be null)
        var familyNote: FoodNotesResponse? = nil
        if let familyNoteDict = jsonObject["familyNote"] as? [String: Any],
           let version = familyNoteDict["version"] as? Int,
           let updatedAt = familyNoteDict["updatedAt"] as? String,
           let content = familyNoteDict["content"] as? [String: Any] {
            familyNote = FoodNotesResponse(content: content, version: version, updatedAt: updatedAt)
        }
        
        // Parse memberNotes (dictionary of member ID -> FoodNotesResponse)
        var memberNotes: [String: FoodNotesResponse] = [:]
        if let memberNotesDict = jsonObject["memberNotes"] as? [String: [String: Any]] {
            for (memberId, noteDict) in memberNotesDict {
                if let version = noteDict["version"] as? Int,
                   let updatedAt = noteDict["updatedAt"] as? String,
                   let content = noteDict["content"] as? [String: Any] {
                    memberNotes[memberId] = FoodNotesResponse(content: content, version: version, updatedAt: updatedAt)
                }
            }
        }
        
        print("[WebService] fetchFoodNotesAll: ✅ Success! Family note: \(familyNote != nil ? "present" : "null"), Member notes: \(memberNotes.count)")
        
        return FoodNotesAllResponse(familyNote: familyNote, memberNotes: memberNotes)
    }
    
    func updateFoodNotes(content: [String: Any], version: Int) async throws -> FoodNotesResponse {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        // Convert content to JSON
        let requestBody: [String: Any] = [
            "content": content,
            "version": version
        ]
        
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let request = SupabaseRequestBuilder(endpoint: .family_food_notes)
            .setAuthorization(with: token)
            .setMethod(to: "PUT")
            .setJsonBody(to: requestBodyData)
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("[WebService] updateFoodNotes: Raw response body (pretty-printed if JSON):\n\(prettyPrintedJSON(from: data))")
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[WebService] updateFoodNotes failed with status \(httpResponse.statusCode): \(errorMessage)")
            
            // Handle version mismatch (409 Conflict) - backend now returns currentNote in response.
            // For family notes, currentNote may be null when there is no existing note yet.
            if httpResponse.statusCode == 409 {
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let currentNoteDict = jsonObject["currentNote"] as? [String: Any],
                       let currentVersion = currentNoteDict["version"] as? Int,
                       let currentUpdatedAt = currentNoteDict["updatedAt"] as? String,
                       let currentContent = currentNoteDict["content"] as? [String: Any] {
                        let currentNote = FoodNotesResponse(
                            content: currentContent,
                            version: currentVersion,
                            updatedAt: currentUpdatedAt
                        )
                        print("[WebService] updateFoodNotes: Version mismatch with existing note - current version: \(currentVersion), expected: \(version)")
                        throw VersionMismatchError(currentNote: currentNote, expectedVersion: version)
                    } else {
                        // currentNote is null or missing: treat this as "no existing note",
                        // so retry once with version=0 to create the family note.
                        print("[WebService] updateFoodNotes: version_mismatch with currentNote=null. Retrying once with version=0.")
                        return try await updateFoodNotes(content: content, version: 0)
                    }
                }
            }
            
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        // Parse response - include content, version and updatedAt
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = jsonObject["version"] as? Int,
              let updatedAt = jsonObject["updatedAt"] as? String,
              let content = jsonObject["content"] as? [String: Any] else {
            print("[WebService] updateFoodNotes: Failed to parse response")
            throw NetworkError.decodingError
        }
        
        return FoodNotesResponse(content: content, version: version, updatedAt: updatedAt)
    }
    
    // MARK: - Member-specific Food Notes API
    
    /// Fetch food notes for a specific family member by ID.
    func fetchMemberFoodNotes(memberId: String) async throws -> FoodNotesResponse? {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        print("[WebService] fetchMemberFoodNotes: Starting GET request to /family/members/\(memberId)/food-notes")
        
        let request = SupabaseRequestBuilder(endpoint: .family_member_food_notes, itemId: memberId)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("[WebService] fetchMemberFoodNotes: Raw response body (pretty-printed if JSON):\n\(prettyPrintedJSON(from: data))")
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            // 404 means no food notes exist yet for this member, which is fine
            if httpResponse.statusCode == 404 {
                print("[WebService] fetchMemberFoodNotes: No member food notes found (404), returning nil")
                return nil
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[WebService] fetchMemberFoodNotes: ❌ Failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        // Backend returns null if no food notes exist (status 200 with null body)
        let responseString = String(data: data, encoding: .utf8) ?? ""
        if responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" || data.isEmpty {
            print("[WebService] fetchMemberFoodNotes: No food notes found (null response), returning nil")
            return nil
        }
        
        // Parse response - include content, version and updatedAt
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = jsonObject["version"] as? Int,
              let updatedAt = jsonObject["updatedAt"] as? String,
              let content = jsonObject["content"] as? [String: Any] else {
            print("[WebService] fetchMemberFoodNotes: ❌ Failed to parse response")
            print("[WebService] fetchMemberFoodNotes: Response body: \(responseString)")
            throw NetworkError.decodingError
        }
        
        print("[WebService] fetchMemberFoodNotes: ✅ Success! Version: \(version), Content keys: \(content.keys.joined(separator: ", "))")
        
        return FoodNotesResponse(content: content, version: version, updatedAt: updatedAt)
    }
    
    /// Update food notes for a specific family member by ID.
    func updateMemberFoodNotes(memberId: String, content: [String: Any], version: Int) async throws -> FoodNotesResponse {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        // Convert content to JSON
        let requestBody: [String: Any] = [
            "content": content,
            "version": version
        ]
        
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let request = SupabaseRequestBuilder(endpoint: .family_member_food_notes, itemId: memberId)
            .setAuthorization(with: token)
            .setMethod(to: "PUT")
            .setJsonBody(to: requestBodyData)
            .build()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("[WebService] updateMemberFoodNotes: Raw response body (pretty-printed if JSON):\n\(prettyPrintedJSON(from: data))")
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[WebService] updateMemberFoodNotes failed with status \(httpResponse.statusCode): \(errorMessage)")
            
            // Handle version mismatch (409 Conflict).
            // For member notes, the backend may return { "error": "version_mismatch", "currentNote": null }
            // when there is no existing note yet. In that case we should retry once with version=0.
            if httpResponse.statusCode == 409 {
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let currentNoteDict = jsonObject["currentNote"] as? [String: Any],
                       let currentVersion = currentNoteDict["version"] as? Int,
                       let currentUpdatedAt = currentNoteDict["updatedAt"] as? String,
                       let currentContent = currentNoteDict["content"] as? [String: Any] {
                        let currentNote = FoodNotesResponse(
                            content: currentContent,
                            version: currentVersion,
                            updatedAt: currentUpdatedAt
                        )
                        print("[WebService] updateMemberFoodNotes: Version mismatch with existing note - current version: \(currentVersion), expected: \(version)")
                        throw VersionMismatchError(currentNote: currentNote, expectedVersion: version)
                    } else {
                        // currentNote is null or missing: treat this as "no existing note",
                        // so retry once with version=0 to create the member note.
                        print("[WebService] updateMemberFoodNotes: version_mismatch with currentNote=null. Retrying once with version=0.")
                        return try await updateMemberFoodNotes(memberId: memberId, content: content, version: 0)
                    }
                }
            }
            
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        // Parse response - include content, version and updatedAt
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = jsonObject["version"] as? Int,
              let updatedAt = jsonObject["updatedAt"] as? String,
              let content = jsonObject["content"] as? [String: Any] else {
            print("[WebService] updateMemberFoodNotes: Failed to parse response")
            print("[WebService] updateMemberFoodNotes: Response body: \(String(data: data, encoding: .utf8) ?? "")")
            throw NetworkError.decodingError
        }
        
        return FoodNotesResponse(content: content, version: version, updatedAt: updatedAt)
    }
    // MARK: - Feedback API

    func submitFeedback(request: DTO.FeedbackRequest) async throws -> DTO.Scan {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }
        
        let requestBody = try JSONEncoder().encode(request)
        if let jsonString = String(data: requestBody, encoding: .utf8) {
            print("[WebService] submitFeedback Request Body: \(jsonString)")
        }
        
        let urlRequest = SupabaseRequestBuilder(endpoint: .scan_feedback)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setJsonBody(to: requestBody)
            .build()
        
        print("[WebService] submitFeedback URL: \(urlRequest.url?.absoluteString ?? "nil")")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(0)
        }
        
        if httpResponse.statusCode == 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("[WebService] submitFeedback Response Body: \(responseString)")
            }
            do {
                let scan = try JSONDecoder().decode(DTO.Scan.self, from: data)
                return scan
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            print("Feedback API Error Status: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func updateFeedback(feedbackId: String, vote: String) async throws -> DTO.Scan {
        guard let token = try? await supabaseClient.auth.session.accessToken else {
             throw NetworkError.authError
        }
        
        let updateRequest = DTO.FeedbackUpdateRequest(vote: vote)
        let requestBody = try JSONEncoder().encode(updateRequest)
        if let jsonString = String(data: requestBody, encoding: .utf8) {
            print("[WebService] updateFeedback Request Body: \(jsonString)")
        }
        
        let urlRequest = SupabaseRequestBuilder(endpoint: .scan_feedback_update, itemId: feedbackId)
            .setAuthorization(with: token)
            .setMethod(to: "PATCH")
            .setJsonBody(to: requestBody)
            .build()
        
        print("[WebService] updateFeedback URL: \(urlRequest.url?.absoluteString ?? "nil")")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             throw NetworkError.invalidResponse(0)
        }
         
        if httpResponse.statusCode == 200 {
             if let responseString = String(data: data, encoding: .utf8) {
                 print("[WebService] updateFeedback Response Body: \(responseString)")
             }
             do {
                 let scan = try JSONDecoder().decode(DTO.Scan.self, from: data)
                 return scan
             } catch {
                 print("Decoding error: \(error)")
                 throw NetworkError.decodingError
             }
        } else {
             throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
}
