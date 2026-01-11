# Scan API Integration Guide

This guide explains how to integrate the new Scan API endpoints into the IngrediCheck iOS app.

## Overview

The new Scan API provides a unified system for barcode and photo-based product scans. It differs from the current `streamUnifiedAnalysis` approach:

| Feature | Current (`analyze-stream`) | New Scan API |
|---------|---------------------------|--------------|
| Barcode lookup | Client sends barcode | Server looks up OpenFoodFacts |
| Photo scans | Images sent with request | Images uploaded incrementally |
| Scan persistence | No server-side history | Full scan history with images |
| Analysis | Runs inline | Runs after product info found |

## New Endpoints

Add these to `SafeEatsEndpoint`:

```swift
enum SafeEatsEndpoint: String {
    // ... existing endpoints ...

    // New Scan API endpoints
    case scan_barcode = "scan/barcode"
    case scan_image = "scan/%@/image"      // scan_id
    case scan_get = "scan/%@"              // scan_id
    case scan_history = "scan/history"
}
```

---

## 1. Barcode Scan (SSE)

**Endpoint:** `POST /scan/barcode`

This is similar to the existing `streamUnifiedAnalysis` but simpler - it handles OpenFoodFacts lookup server-side.

### Add to WebService.swift

```swift
// MARK: - Scan API

struct ScanStreamError: Error, LocalizedError {
    let message: String
    let statusCode: Int?
    var errorDescription: String? { message }
}

func streamBarcodeScan(
    barcode: String,
    onProductInfo: @escaping (DTO.ScanProductInfo, String) -> Void,  // (productInfo, scanId)
    onAnalysis: @escaping (DTO.ScanAnalysisResult) -> Void,
    onError: @escaping (ScanStreamError, String?) -> Void  // (error, scanId)
) async throws {

    let requestId = UUID().uuidString
    let startTime = Date().timeIntervalSince1970
    var scanId: String?
    var hasReportedError = false

    guard let token = try? await supabaseClient.auth.session.accessToken else {
        throw NetworkError.authError
    }

    let requestBody = try JSONEncoder().encode(["barcode": barcode])

    var request = SupabaseRequestBuilder(endpoint: .scan_barcode)
        .setAuthorization(with: token)
        .setMethod(to: "POST")
        .setJsonBody(to: requestBody)
        .build()

    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 60

    PostHogSDK.shared.capture("Barcode Scan Started", properties: [
        "request_id": requestId,
        "barcode": barcode
    ])

    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        PostHogSDK.shared.capture("Barcode Scan Failed - HTTP", properties: [
            "request_id": requestId,
            "status_code": statusCode
        ])
        throw NetworkError.invalidResponse(statusCode)
    }

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
            do {
                let event = try JSONDecoder().decode(DTO.ScanProductInfoEvent.self, from: payloadData)
                scanId = event.scan_id

                let latency = (Date().timeIntervalSince1970 - startTime) * 1000
                PostHogSDK.shared.capture("Barcode Scan Product Info", properties: [
                    "request_id": requestId,
                    "scan_id": event.scan_id,
                    "source": event.product_info_source,
                    "latency_ms": latency
                ])

                await MainActor.run {
                    onProductInfo(event.product_info, event.scan_id)
                }
            } catch {
                print("Failed to decode product_info: \(error)")
            }

        case "analysis":
            do {
                let event = try JSONDecoder().decode(DTO.ScanAnalysisEvent.self, from: payloadData)

                PostHogSDK.shared.capture("Barcode Scan Analysis", properties: [
                    "request_id": requestId,
                    "scan_id": scanId ?? "unknown"
                ])

                await MainActor.run {
                    onAnalysis(event.analysis_result)
                }
            } catch {
                print("Failed to decode analysis: \(error)")
            }

        case "error":
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

            PostHogSDK.shared.capture("Barcode Scan Error", properties: [
                "request_id": requestId,
                "scan_id": scanId ?? "unknown",
                "error": errorMessage
            ])

            await MainActor.run {
                onError(ScanStreamError(message: errorMessage, statusCode: nil), scanId)
            }

        case "done":
            break

        default:
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
            await MainActor.run {
                onError(ScanStreamError(message: error.localizedDescription, statusCode: nil), scanId)
            }
        }
        throw error
    }
}
```

---

## 2. Submit Image (Photo Scan)

**Endpoint:** `POST /scan/{scan_id}/image`

### Important: Client Generates the Scan ID

For photo scans, **your app generates the UUID**:

```swift
let scanId = UUID().uuidString
```

If no scan exists with that ID, the server creates one. This lets you:
- Submit multiple photos without waiting for responses
- Handle offline/retry scenarios
- Track the scan locally before server confirms

### Add to WebService.swift

```swift
func submitScanImage(
    scanId: String,
    imageData: Data
) async throws -> DTO.SubmitImageResponse {

    guard let token = try? await supabaseClient.auth.session.accessToken else {
        throw NetworkError.authError
    }

    let request = SupabaseRequestBuilder(endpoint: .scan_image, itemId: scanId)
        .setAuthorization(with: token)
        .setMethod(to: "POST")
        .setFormData(name: "image", value: imageData, contentType: "image/jpeg")
        .build()

    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = response as! HTTPURLResponse

    switch httpResponse.statusCode {
    case 200:
        return try JSONDecoder().decode(DTO.SubmitImageResponse.self, from: data)
    case 401:
        throw NetworkError.authError
    case 403:
        throw NetworkError.notFound("Scan belongs to another user")
    case 413:
        throw NetworkError.invalidResponse(413)  // Image too large (>10MB)
    case 400:
        throw NetworkError.invalidResponse(400)  // Max images reached (20)
    default:
        throw NetworkError.invalidResponse(httpResponse.statusCode)
    }
}
```

---

## 3. Get Scan

**Endpoint:** `GET /scan/{scan_id}`

Use this to poll for updates after submitting images.

### Add to WebService.swift

```swift
func getScan(scanId: String) async throws -> DTO.Scan {

    guard let token = try? await supabaseClient.auth.session.accessToken else {
        throw NetworkError.authError
    }

    let request = SupabaseRequestBuilder(endpoint: .scan_get, itemId: scanId)
        .setAuthorization(with: token)
        .setMethod(to: "GET")
        .build()

    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = response as! HTTPURLResponse

    switch httpResponse.statusCode {
    case 200:
        return try JSONDecoder().decode(DTO.Scan.self, from: data)
    case 401:
        throw NetworkError.authError
    case 403:
        throw NetworkError.notFound("Scan belongs to another user")
    case 404:
        throw NetworkError.notFound("Scan not found")
    default:
        throw NetworkError.invalidResponse(httpResponse.statusCode)
    }
}
```

---

## 4. Scan History

**Endpoint:** `GET /scan/history?limit=20&offset=0`

Returns paginated scan history with full scan objects (including `product_info`, `analysis_result`, and `images`).

### Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | int | 20 | Number of scans to return (1-100) |
| `offset` | int | 0 | Number of scans to skip |

### Add to WebService.swift

```swift
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
```

---

## 5. DTO Models

Add these to `DTO.swift`:

```swift
// MARK: - Scan API Models

struct ScanProductInfo: Codable, Hashable {
    let name: String?
    let brand: String?
    let ingredients: [Ingredient]
    let images: [ScanImageInfo]?
}

struct ScanImageInfo: Codable, Hashable {
    let url: String?
}

struct ScanAnalysisResult: Codable, Hashable {
    let overall_analysis: String
    let overall_match: String  // "matched", "uncertain", "unmatched"
    let ingredient_analysis: [ScanIngredientAnalysis]
}

struct ScanIngredientAnalysis: Codable, Hashable {
    let ingredient: String
    let match: String  // "unmatched", "uncertain"
    let reasoning: String
    let members_affected: [String]
}

// SSE Event payloads
struct ScanProductInfoEvent: Codable {
    let scan_id: String
    let product_info: ScanProductInfo
    let product_info_source: String
    let images: [ScanImage]
}

struct ScanAnalysisEvent: Codable {
    let analysis_status: String
    let analysis_result: ScanAnalysisResult
}

// Image types in scan response
enum ScanImage: Codable, Hashable {
    case inventory(InventoryScanImage)
    case user(UserScanImage)

    struct InventoryScanImage: Codable, Hashable {
        let type: String  // "inventory"
        let url: String
    }

    struct UserScanImage: Codable, Hashable {
        let type: String  // "user"
        let content_hash: String
        let storage_path: String?
        let status: String  // "pending", "processing", "processed", "failed"
        let extraction_error: String?
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "inventory":
            self = .inventory(try InventoryScanImage(from: decoder))
        case "user":
            self = .user(try UserScanImage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown image type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .inventory(let img):
            try img.encode(to: encoder)
        case .user(let img):
            try img.encode(to: encoder)
        }
    }
}

// Full Scan object
struct Scan: Codable, Hashable {
    let id: String
    let scan_type: String  // "barcode" or "photo"
    let barcode: String?
    let status: String  // "idle" or "processing"
    let product_info: ScanProductInfo
    let product_info_source: String?  // "openfoodfacts", "extraction", "enriched"
    let analysis_status: String?  // "analyzing", "complete", "stale"
    let analysis_result: ScanAnalysisResult?
    let images: [ScanImage]
    let latest_guidance: String?
    let created_at: String
    let last_activity_at: String
}

// Submit image response
struct SubmitImageResponse: Codable {
    let queued: Bool
    let queue_position: Int
    let content_hash: String
}

// Scan history response
struct ScanHistoryResponse: Codable {
    let scans: [Scan]
    let total: Int
    let has_more: Bool
}
```

---

## 6. View Examples

Following the MV pattern, Views directly consume `WebService` via `@Environment` and use `@State` for local view state.

### Barcode Scan View

```swift
struct BarcodeScanView: View {
    let barcode: String

    @Environment(WebService.self) var webService

    @State private var scanId: String?
    @State private var productInfo: DTO.ScanProductInfo?
    @State private var analysisResult: DTO.ScanAnalysisResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var productNotFound = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Scanning...")
            } else if let productInfo {
                ProductInfoView(productInfo: productInfo, analysisResult: analysisResult)
            } else if productNotFound {
                ProductNotFoundView(scanId: scanId, onAddPhoto: addPhoto)
            } else if let errorMessage {
                ErrorView(message: errorMessage)
            }
        }
        .task {
            await startScan()
        }
    }

    private func startScan() async {
        isLoading = true
        errorMessage = nil
        productNotFound = false

        do {
            try await webService.streamBarcodeScan(
                barcode: barcode,
                onProductInfo: { productInfo, id in
                    self.productInfo = productInfo
                    self.scanId = id
                },
                onAnalysis: { analysis in
                    self.analysisResult = analysis
                    self.isLoading = false
                },
                onError: { error, id in
                    self.scanId = id
                    if error.message.contains("not found") {
                        self.productNotFound = true
                    } else {
                        self.errorMessage = error.message
                    }
                    self.isLoading = false
                }
            )
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func addPhoto(_ image: UIImage) async {
        guard let scanId,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        isLoading = true

        do {
            _ = try await webService.submitScanImage(scanId: scanId, imageData: imageData)
            await pollForUpdates()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func pollForUpdates() async {
        guard let scanId else { return }

        while isLoading {
            do {
                let scan = try await webService.getScan(scanId: scanId)
                productInfo = scan.product_info
                analysisResult = scan.analysis_result

                if scan.status == "idle" {
                    isLoading = false
                    productNotFound = false
                    break
                }

                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                isLoading = false
                break
            }
        }
    }
}
```

### Photo Scan View

```swift
struct PhotoScanView: View {
    @Environment(WebService.self) var webService

    // Client generates UUID for new scan
    @State private var scanId = UUID().uuidString
    @State private var scan: DTO.Scan?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var guidanceMessage: String?

    var body: some View {
        VStack {
            if let scan {
                ScanResultView(scan: scan)
            }

            if let guidanceMessage {
                Text(guidanceMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if isProcessing {
                ProgressView("Processing...")
            }

            CaptureButton(onCapture: addPhoto)
                .disabled(isProcessing)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private func addPhoto(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        isProcessing = true
        errorMessage = nil

        do {
            let response = try await webService.submitScanImage(
                scanId: scanId,
                imageData: imageData
            )
            print("Image \(response.content_hash) queued at position \(response.queue_position)")

            await pollForUpdates()
        } catch let error as NetworkError {
            switch error {
            case .invalidResponse(413):
                errorMessage = "Image too large. Please use a smaller image."
            case .invalidResponse(400):
                errorMessage = "Maximum images reached for this scan."
            default:
                errorMessage = "Failed to upload image."
            }
            isProcessing = false
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }

    private func pollForUpdates() async {
        while isProcessing {
            do {
                let scan = try await webService.getScan(scanId: scanId)
                self.scan = scan
                self.guidanceMessage = scan.latest_guidance

                if scan.status == "idle" && scan.analysis_status == "complete" {
                    isProcessing = false
                    break
                }

                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                isProcessing = false
                break
            }
        }
    }

    private func reset() {
        scanId = UUID().uuidString
        scan = nil
        isProcessing = false
        errorMessage = nil
        guidanceMessage = nil
    }
}
```

### Scan History View

```swift
struct ScanHistoryView: View {
    @Environment(WebService.self) var webService

    @State private var scans: [DTO.Scan] = []
    @State private var total = 0
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var currentOffset = 0

    private let pageSize = 20

    var body: some View {
        List {
            ForEach(scans, id: \.id) { scan in
                ScanRowView(scan: scan)
                    .onAppear {
                        if scan.id == scans.last?.id && hasMore {
                            Task { await loadMore() }
                        }
                    }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .task {
            await loadInitial()
        }
        .refreshable {
            await loadInitial()
        }
    }

    private func loadInitial() async {
        currentOffset = 0
        scans = []
        await loadMore()
    }

    private func loadMore() async {
        guard !isLoading else { return }

        isLoading = true

        do {
            let response = try await webService.fetchScanHistory(
                limit: pageSize,
                offset: currentOffset
            )

            scans.append(contentsOf: response.scans)
            total = response.total
            hasMore = response.has_more
            currentOffset += response.scans.count
        } catch {
            print("Failed to load scan history: \(error)")
        }

        isLoading = false
    }
}
```

---

## Key Differences from Current Implementation

1. **Scan ID Management**
   - Barcode scan: Server generates `scan_id`, returned in `product_info` event
   - Photo scan: Client generates `scan_id` as `UUID().uuidString` before first image upload

2. **SSE Events**
   - Current: `product`, `analysis`, `error`
   - New: `product_info`, `analysis`, `error`, `done`

3. **Image Storage**
   - Current: Images uploaded to `productimages` bucket, hash returned
   - New: Images uploaded to `scan-images` bucket via `/scan/{id}/image` endpoint

4. **Analysis Trigger**
   - Current: Analysis runs during stream
   - New: Analysis runs after ingredients are found (either from OpenFoodFacts or extraction)

5. **Polling**
   - Current: SSE stream provides all data
   - New: Use `GET /scan/{id}` to poll for photo scan updates

---

## Testing Tips

1. **Known Barcode:** `3017620422003` (Nutella) - should return product info
2. **Unknown Barcode:** `0000000000000` - should return error event with scan_id
3. **Image Size:** Max 10MB per image
4. **Image Count:** Max 20 images per scan
