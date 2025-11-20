import Foundation
import SwiftUI
import CryptoKit
import Supabase
import PostHog

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

        var fileLocation: FileLocation {
            switch imageLocation {
            case .url(let url):
                return FileLocation.url(url)
            case .imageFileHash(let imageFileHash):
                return FileLocation.supabase(SupabaseFile(bucket: "productimages", name: imageFileHash))
            }
        }
        
        var imageData: Data {
            get async throws {
                switch imageSize {
                case .small:
                    return try await smallImageStore.fetchFile(fileLocation: fileLocation)
                case .medium:
                    return try await mediumImageStore.fetchFile(fileLocation: fileLocation)
                case .large:
                    return try await largeImageStore.fetchFile(fileLocation: fileLocation)
                }
            }
        }
        
        return UIImage(data: try await imageData)!
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
        case .productImages(let productImages):
            let productImagesDTO = try await productImages.asyncMap { productImage in
                DTO.ImageInfo(
                    imageFileHash: try await productImage.uploadTask.value,
                    imageOCRText: try await productImage.ocrTask.value,
                    barcode: try await productImage.barcodeDetectionTask.value
                )
            }

            let productImagesData = try JSONEncoder().encode(productImagesDTO)
            guard let productImagesString = String(data: productImagesData, encoding: .utf8) else {
                throw NetworkError.decodingError
            }

            requestBuilder = requestBuilder.setFormData(name: "productImages", value: productImagesString)
            analyticsProperties["input_type"] = "product_images"
            analyticsProperties["image_count"] = productImages.count
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
                DTO.ImageInfo(
                    imageFileHash: try await productImage.uploadTask.value,
                    imageOCRText: try await productImage.ocrTask.value,
                    barcode: try await productImage.barcodeDetectionTask.value
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

        let imageData = image.jpegData(compressionQuality: 1.0)!
        let imageFileName = SHA256.hash(data: imageData).compactMap { String(format: "%02x", $0) }.joined()

        try await supabaseClient.storage.from("productimages").upload(
            path: imageFileName,
            file: imageData,
            options: FileOptions(contentType: "image/jpeg")
        )

        return imageFileName
    }

    func deleteImages(imageFileNames: [String]) async throws {
        _ = try await supabaseClient.storage.from("productimages").remove(paths: imageFileNames)
    }

    func addToFavorites(clientActivityId: String) async throws {
        
        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let listId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!.uuidString
        let request = SupabaseRequestBuilder(endpoint: .list_items, itemId: listId)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .build()

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 201 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    func removeFromFavorites(clientActivityId: String) async throws {

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let listId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!.uuidString
        let request = SupabaseRequestBuilder(endpoint: .list_items_item, itemId: listId, subItemId: clientActivityId)
            .setAuthorization(with: token)
            .setMethod(to: "DELETE")
            .build()

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
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
}
