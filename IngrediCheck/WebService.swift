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

    func fetchProductDetailsFromBarcode(
        clientActivityId: String,
        barcode: String
    ) async throws -> DTO.Product {

        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let request = SupabaseRequestBuilder(endpoint: .inventory, itemId: barcode)
            .setQueryItems(queryItems: [
                URLQueryItem(name: "clientActivityId", value: clientActivityId)
            ])
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()

        print(request)

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")

            PostHogSDK.shared.capture("Barcode Lookup Failed", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "status_code": httpResponse.statusCode,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            if httpResponse.statusCode == 404 {
                print("Not found")
                throw NetworkError.notFound("Product with barcode \(barcode) not found in Inventory")
            } else {
                throw NetworkError.invalidResponse(httpResponse.statusCode)
            }
        }

        do {
            let product = try JSONDecoder().decode(DTO.Product.self, from: data)

            PostHogSDK.shared.capture("Barcode Lookup Successful", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "product_name": product.name ?? "Unknown",
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            return product
        } catch {
            print("Failed to decode Product object: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)

            PostHogSDK.shared.capture("Barcode Lookup Decode Error", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "error": error.localizedDescription,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.decodingError
        }
    }
    
    func extractProductDetailsFromLabelImages(
        clientActivityId: String,
        productImages: [ProductImage]
    ) async throws -> DTO.Product {

        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        let productImagesDTO = try await productImages.asyncMap { productImage in
            DTO.ImageInfo(
                imageFileHash: try await productImage.uploadTask.value,
                imageOCRText: try await productImage.ocrTask.value,
                barcode: try await productImage.barcodeDetectionTask.value
            )
        }

        let productImagesJsonData = try JSONEncoder().encode(productImagesDTO)
        let productImagesJsonString = String(data: productImagesJsonData, encoding: .utf8)!

        print(productImagesJsonString)

        let request = SupabaseRequestBuilder(endpoint: .extract)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "productImages", value: productImagesJsonString)
            .build()

        print(request)

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")

            PostHogSDK.shared.capture("Label Extraction Failed", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "image_count": productImages.count,
                "status_code": httpResponse.statusCode,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        do {
            let product = try JSONDecoder().decode(DTO.Product.self, from: data)

            PostHogSDK.shared.capture("Label Extraction Successful", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "image_count": productImages.count,
                "product_name": product.name ?? "Unknown",
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            print(product)
            return product
        } catch {
            print("Failed to decode Product object: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)

            PostHogSDK.shared.capture("Label Extraction Decode Error", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "image_count": productImages.count,
                "error": error.localizedDescription,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.decodingError
        }
    }
    
    func fetchIngredientRecommendations(
        clientActivityId: String,
        userPreferenceText: String,
        barcode: String? = nil
    ) async throws -> [DTO.IngredientRecommendation] {

        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            throw NetworkError.authError
        }

        var requestBuilder = SupabaseRequestBuilder(endpoint: .analyze)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "userPreferenceText", value: userPreferenceText)

        if let barcode = barcode {
            requestBuilder = requestBuilder.setFormData(name: "barcode", value: barcode)
        }

        let request = requestBuilder.build()

        print("Fetching recommendations")
        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")

            PostHogSDK.shared.capture("Ingredient Analysis Failed", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "has_barcode": barcode != nil,
                "preference_length": userPreferenceText.count,
                "status_code": httpResponse.statusCode,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        do {
            let ingredientRecommendations = try JSONDecoder().decode([DTO.IngredientRecommendation].self, from: data)

            PostHogSDK.shared.capture("Ingredient Analysis Successful", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "has_barcode": barcode != nil,
                "preference_length": userPreferenceText.count,
                "recommendations_count": ingredientRecommendations.count,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            print(ingredientRecommendations)
            return ingredientRecommendations
        } catch {
            print("Failed to decode IngredientRecommendation array: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print(responseText)

            PostHogSDK.shared.capture("Ingredient Analysis Decode Error", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "has_barcode": barcode != nil,
                "preference_length": userPreferenceText.count,
                "error": error.localizedDescription,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.decodingError
        }
    }

    func streamInventoryAndAnalysis(
        clientActivityId: String,
        barcode: String,
        userPreferenceText: String,
        onProduct: @escaping (DTO.Product) -> Void,
        onAnalysis: @escaping ([DTO.IngredientRecommendation]) -> Void,
        onError: @escaping (String) -> Void
    ) async throws {

        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        var productReceivedTime: TimeInterval?
        var analysisReceivedTime: TimeInterval?

        print("🔄 [SSE] Starting stream for barcode: \(barcode), clientActivityId: \(clientActivityId)")

        guard let token = try? await supabaseClient.auth.session.accessToken else {
            print("❌ [SSE] Authentication failed - no access token")
            throw NetworkError.authError
        }

        var queryItems = [URLQueryItem(name: "clientActivityId", value: clientActivityId)]

        if !userPreferenceText.isEmpty && userPreferenceText.lowercased() != "none" {
            queryItems.append(URLQueryItem(name: "userPreferenceText", value: userPreferenceText))
        }

        let request = SupabaseRequestBuilder(endpoint: .inventory_analyze_stream, itemId: barcode)
            .setQueryItems(queryItems: queryItems)
            .setAuthorization(with: token)
            .setMethod(to: "GET")
            .build()

        print("🌐 [SSE] Request URL: \(request.url?.absoluteString ?? "nil")")
        print("📋 [SSE] Query items: \(queryItems)")

        PostHogSDK.shared.capture("Stream Analysis Started", properties: [
            "request_id": requestId,
            "client_activity_id": clientActivityId,
            "barcode": barcode,
            "has_preferences": !userPreferenceText.isEmpty && userPreferenceText.lowercased() != "none"
        ])

        print("📡 [SSE] Making network request...")
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        print("✅ [SSE] Network request completed")

        let httpResponse = response as! HTTPURLResponse
        print("📊 [SSE] HTTP Status: \(httpResponse.statusCode)")
        print("🔍 [SSE] Response headers: \(httpResponse.allHeaderFields)")

        guard httpResponse.statusCode == 200 else {
            print("❌ [SSE] Bad HTTP status: \(httpResponse.statusCode)")
            PostHogSDK.shared.capture("Stream Analysis Failed", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "status_code": httpResponse.statusCode,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        var buffer = ""
        var byteCount = 0

        print("🔄 [SSE] Starting to read bytes...")
        do {
            for try await byte in asyncBytes {
                byteCount += 1
                let scalar = UnicodeScalar(byte)
                let character = Character(scalar)
                buffer.append(character)

                if byteCount % 100 == 0 {
                    print("📊 [SSE] Read \(byteCount) bytes so far...")
                }

                if buffer.hasSuffix("\n\n") {
                    let lines = buffer.components(separatedBy: "\n").filter { !$0.isEmpty }
                    print("📨 [SSE] Received SSE event with \(lines.count) lines: \(lines)")
                    buffer = ""

                    // Skip comment lines (lines starting with ":")
                    let dataLines = lines.filter { !$0.hasPrefix(":") }

                    for line in dataLines {
                        if line.hasPrefix("data:") {
                            let eventDataString = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))

                            // Parse the nested JSON structure
                            if let eventJsonData = eventDataString.data(using: .utf8),
                               let eventWrapper = try? JSONDecoder().decode([String: String].self, from: eventJsonData),
                               let eventType = eventWrapper["event"],
                               let eventDataJson = eventWrapper["data"] {

                                print("🎯 [SSE] Processing event type: \(eventType) with data length: \(eventDataJson.count)")

                                switch eventType {
                                case "product":
                                    productReceivedTime = Date().timeIntervalSince1970
                                    let productLatency = (productReceivedTime! - startTime) * 1000

                                    print("📦 [SSE] Received product event (latency: \(Int(productLatency))ms)")
                                    if let jsonData = eventDataJson.data(using: .utf8),
                                       let product = try? JSONDecoder().decode(DTO.Product.self, from: jsonData) {
                                        print("✅ [SSE] Successfully decoded product: \(product.name ?? "unnamed")")

                                        PostHogSDK.shared.capture("Stream Product Received", properties: [
                                            "request_id": requestId,
                                            "client_activity_id": clientActivityId,
                                            "barcode": barcode,
                                            "product_name": product.name ?? "Unknown",
                                            "product_latency_ms": productLatency
                                        ])

                                        onProduct(product)
                                    } else {
                                        print("❌ [SSE] Failed to decode product data")
                                    }
                                case "analysis":
                                    analysisReceivedTime = Date().timeIntervalSince1970
                                    let totalLatency = (analysisReceivedTime! - startTime) * 1000
                                    let analysisLatency = productReceivedTime != nil ? (analysisReceivedTime! - productReceivedTime!) * 1000 : totalLatency

                                    print("🧪 [SSE] Received analysis event (analysis latency: \(Int(analysisLatency))ms, total: \(Int(totalLatency))ms)")
                                    if let jsonData = eventDataJson.data(using: .utf8),
                                       let analysis = try? JSONDecoder().decode([DTO.IngredientRecommendation].self, from: jsonData) {
                                        print("✅ [SSE] Successfully decoded analysis with \(analysis.count) recommendations")

                                        PostHogSDK.shared.capture("Stream Analysis Received", properties: [
                                            "request_id": requestId,
                                            "client_activity_id": clientActivityId,
                                            "barcode": barcode,
                                            "recommendations_count": analysis.count,
                                            "analysis_latency_ms": analysisLatency,
                                            "total_latency_ms": totalLatency,
                                            "product_latency_ms": productReceivedTime != nil ? (productReceivedTime! - startTime) * 1000 : nil
                                        ])

                                        onAnalysis(analysis)
                                    } else {
                                        print("❌ [SSE] Failed to decode analysis data")
                                    }
                                case "error":
                                    print("💥 [SSE] Received error event")
                                    print("🔍 [SSE] Raw error data: \(eventDataJson)")

                                    // Define simple error response structure
                                    struct ErrorResponse: Codable {
                                        let message: String
                                        let status: Int?
                                    }

                                    if let jsonData = eventDataJson.data(using: .utf8),
                                       let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: jsonData) {

                                        print("❌ [SSE] Server error: \(errorResponse.message) (status: \(errorResponse.status ?? 0))")
                                        PostHogSDK.shared.capture("Stream Analysis Server Error", properties: [
                                            "request_id": requestId,
                                            "client_activity_id": clientActivityId,
                                            "barcode": barcode,
                                            "error_message": errorResponse.message,
                                            "error_status": errorResponse.status ?? 0,
                                            "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
                                        ])

                                        onError(errorResponse.message)
                                        return
                                    } else {
                                        print("❌ [SSE] Failed to parse error message from: \(eventDataJson)")
                                        // Fallback: try to extract message directly from the raw string
                                        if eventDataJson.contains("not found") {
                                            print("🔧 [SSE] Fallback: detected 'not found' in raw data")
                                            onError("Product not found.")
                                            return
                                        }
                                    }
                                default:
                                    print("❓ [SSE] Unknown event type: \(eventType)")
                                    break
                                }
                            } else {
                                print("⚠️ [SSE] Could not parse nested JSON from line: \(line)")
                            }
                        }
                    }
                }
            }

            let endTime = Date().timeIntervalSince1970
            let finalTotalLatency = (endTime - startTime) * 1000

            print("🎉 [SSE] Stream completed successfully after reading \(byteCount) bytes (total: \(Int(finalTotalLatency))ms)")

            // Final summary event with all latency metrics
            var completionProperties: [String: Any] = [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "total_latency_ms": finalTotalLatency,
                "bytes_received": byteCount
            ]

            if let productTime = productReceivedTime {
                completionProperties["product_latency_ms"] = (productTime - startTime) * 1000
            }

            if let analysisTime = analysisReceivedTime, let productTime = productReceivedTime {
                completionProperties["analysis_latency_ms"] = (analysisTime - productTime) * 1000
                completionProperties["analysis_total_latency_ms"] = (analysisTime - startTime) * 1000
            }

            PostHogSDK.shared.capture("Stream Analysis Completed", properties: completionProperties)

        } catch {
            print("❌ [SSE] Stream error: \(error.localizedDescription)")
            PostHogSDK.shared.capture("Stream Analysis Connection Error", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "error": error.localizedDescription,
                "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
            ])

            throw error
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
        
        print(feedbackDataJsonString)

        let request = SupabaseRequestBuilder(endpoint: .feedback)
            .setAuthorization(with: token)
            .setMethod(to: "POST")
            .setFormData(name: "clientActivityId", value: clientActivityId)
            .setFormData(name: "feedback", value: feedbackDataJsonString)
            .build()

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 201 else {
            print("Bad response from server: \(httpResponse.statusCode)")
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

        print(request)

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            print("Bad response from server: \(httpResponse.statusCode)")

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
            print("Failed to decode History object: \(error)")
            let responseText = String(data: data, encoding: .utf8) ?? ""
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
}
