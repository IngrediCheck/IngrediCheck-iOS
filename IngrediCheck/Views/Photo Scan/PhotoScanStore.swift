import SwiftUI
import Combine

@MainActor
class PhotoScanStore: ObservableObject {
    @Published var scanId: String?
    @Published var scanDetails: DTO.Scan?
    @Published var isUploading: Bool = false
    @Published var isPolling: Bool = false
    @Published var errorMessage: String?
    @Published var isCreatingScan: Bool = false
    @Published var guidanceMessage: String?  // Latest guidance from backend
    
    private var pollingTask: Task<Void, Never>?
    private var webService: WebService?
    
    init(webService: WebService? = nil) {
        self.webService = webService
    }
    
    func setWebService(_ webService: WebService) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 [PhotoScanStore] setWebService called")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        self.webService = webService
        print("[PhotoScanStore] ✅ WebService set successfully")
    }
    
    func startNewScan() async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 [PhotoScanStore] startNewScan() called")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        guard let webService = webService else {
            print("[PhotoScanStore] ❌ WebService not available")
            self.errorMessage = "WebService not available"
            return
        }
        
        print("[PhotoScanStore] Resetting state...")
        self.scanId = nil
        self.scanDetails = nil
        self.errorMessage = nil
        self.isUploading = false
        self.isPolling = false
        self.isCreatingScan = false
        self.guidanceMessage = nil
        self.pollingTask?.cancel()
        print("[PhotoScanStore] ✅ State reset complete")
        
        // Create a new scan on the backend (previous working approach)
        print("[PhotoScanStore] Creating new scan on backend...")
        self.isCreatingScan = true
        do {
            print("[PhotoScanStore] Calling webService.createPhotoScan()...")
            let newScanId = try await webService.createPhotoScan()
            self.scanId = newScanId
            self.isCreatingScan = false
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📱 [PhotoScanStore] ✅ Created new scan with ID: \(newScanId)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        } catch {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📱 [PhotoScanStore] ❌ Failed to create scan: \(error)")
            print("📱 [PhotoScanStore] Error type: \(type(of: error))")
            print("📱 [PhotoScanStore] Error description: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            self.errorMessage = "Failed to create scan: \(error.localizedDescription)"
            self.isCreatingScan = false
        }
    }
    
    func uploadImage(image: UIImage) async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 [PhotoScanStore] uploadImage() called")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("[PhotoScanStore] Image size: \(image.size.width)x\(image.size.height)")
        
        guard let webService = webService else {
            print("[PhotoScanStore] ❌ WebService not available")
            self.errorMessage = "WebService not available"
            return
        }
        
        // If no scanId exists, try to create one first
        if scanId == nil {
            print("[PhotoScanStore] No scan ID, attempting to create scan first...")
            await startNewScan()
            
            // Wait a bit for scan creation to complete
            var waitCount = 0
            while scanId == nil && waitCount < 10 && isCreatingScan {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                waitCount += 1
            }
        }
        
        guard let scanId = scanId else {
            print("[PhotoScanStore] ❌ No scan ID available after creation attempt. Please try again.")
            self.errorMessage = "Failed to create scan. Please try again."
            return
        }
        
        print("[PhotoScanStore] Scan ID: \(scanId)")
        print("[PhotoScanStore] Converting image to JPEG...")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[PhotoScanStore] ❌ Failed to convert image to JPEG")
            self.errorMessage = "Failed to convert image to JPEG"
            return
        }
        
        let imageSizeKB = Double(imageData.count) / 1024.0
        print("[PhotoScanStore] ✅ Image converted to JPEG: \(String(format: "%.2f", imageSizeKB)) KB")
        
        self.isUploading = true
        self.errorMessage = nil
        print("[PhotoScanStore] isUploading set to true")
        
        do {
            print("[PhotoScanStore] Calling webService.submitScanImage()...")
            let response = try await webService.submitScanImage(
                scanId: scanId,
                imageData: imageData
            )
            
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📱 [PhotoScanStore] ✅ Upload successful!")
            print("📱 [PhotoScanStore] Queued: \(response.queued)")
            print("📱 [PhotoScanStore] Queue Position: \(response.queue_position)")
            print("📱 [PhotoScanStore] Content Hash: \(response.content_hash)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            self.isUploading = false
            print("[PhotoScanStore] isUploading set to false")
            
            // Start polling after successful upload
            print("[PhotoScanStore] Starting polling...")
            self.startPolling()
            
        } catch {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📱 [PhotoScanStore] ❌ Upload failed!")
            print("📱 [PhotoScanStore] Error type: \(type(of: error))")
            print("📱 [PhotoScanStore] Error: \(error)")
            print("📱 [PhotoScanStore] Error description: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            self.errorMessage = "Upload failed: \(error.localizedDescription)"
            self.isUploading = false
        }
    }
    
    func startPolling() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 [PhotoScanStore] startPolling() called")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        guard let webService = webService else {
            print("[PhotoScanStore] ❌ WebService not available, cannot start polling")
            return
        }
        
        guard let scanId = self.scanId else {
            print("[PhotoScanStore] ❌ No scan ID available, cannot start polling")
            return
        }
        
        print("[PhotoScanStore] Scan ID: \(scanId)")
        print("[PhotoScanStore] Cancelling previous polling task if any...")
        self.pollingTask?.cancel()
        self.isPolling = true
        print("[PhotoScanStore] isPolling set to true")
        print("[PhotoScanStore] Starting polling task...")
        
        self.pollingTask = Task {
            var pollCount = 0
            
            while !Task.isCancelled {
                pollCount += 1
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("📱 [PhotoScanStore] Poll #\(pollCount) - Fetching scan details...")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                do {
                    let scan = try await webService.getScan(scanId: scanId)
                    
                    print("[PhotoScanStore] ✅ Got scan details:")
                    print("[PhotoScanStore]   - Scan ID: \(scan.id)")
                    print("[PhotoScanStore]   - Scan Type: \(scan.scan_type)")
                    print("[PhotoScanStore]   - Status: \(scan.status)")
                    print("[PhotoScanStore]   - Analysis Status: \(scan.analysis_status ?? "nil")")
                    print("[PhotoScanStore]   - Product Name: \(scan.product_info.name ?? "nil")")
                    print("[PhotoScanStore]   - Product Brand: \(scan.product_info.brand ?? "nil")")
                    print("[PhotoScanStore]   - Has Analysis Result: \(scan.analysis_result != nil)")
                    print("[PhotoScanStore]   - Latest Guidance: \(scan.latest_guidance ?? "nil")")
                    
                    await MainActor.run {
                        self.scanDetails = scan
                        // Update guidance message if available
                        if let guidance = scan.latest_guidance, !guidance.isEmpty {
                            self.guidanceMessage = guidance
                            print("[PhotoScanStore] ✅ Updated guidance message: \(guidance)")
                        }
                        print("[PhotoScanStore] ✅ Updated scanDetails on MainActor")
                    }
                    
                    // Check completion according to document: status == "idle" && analysis_status == "complete"
                    if scan.status == "idle" && scan.analysis_status == "complete" {
                        // Analysis is complete according to document specification
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        print("📱 [PhotoScanStore] ✅ Analysis complete for scan \(scanId)")
                        print("📱 [PhotoScanStore] Status: \(scan.status)")
                        print("📱 [PhotoScanStore] Analysis Status: \(scan.analysis_status ?? "nil")")
                        if let analysisResult = scan.analysis_result {
                            print("📱 [PhotoScanStore] Overall Match: \(analysisResult.overall_match)")
                            print("📱 [PhotoScanStore] Overall Analysis: \(analysisResult.overall_analysis)")
                            print("📱 [PhotoScanStore] Ingredient Analysis Count: \(analysisResult.ingredient_analysis.count)")
                        } else {
                            print("📱 [PhotoScanStore] ⚠️  Analysis status is complete but no analysis_result yet")
                        }
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        
                        await MainActor.run {
                            self.isPolling = false
                            print("[PhotoScanStore] isPolling set to false")
                        }
                        return
                    } else {
                        print("[PhotoScanStore] ⏳ Analysis not complete yet:")
                        print("[PhotoScanStore]   - Status: \(scan.status) (expected: 'idle')")
                        print("[PhotoScanStore]   - Analysis Status: \(scan.analysis_status ?? "nil") (expected: 'complete')")
                        print("[PhotoScanStore] Will poll again in 2 seconds...")
                    }
                    
                    // Wait before next poll (2 seconds)
                    try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    
                } catch {
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("📱 [PhotoScanStore] ❌ Polling error on attempt #\(pollCount)")
                    print("📱 [PhotoScanStore] Error type: \(type(of: error))")
                    print("📱 [PhotoScanStore] Error: \(error)")
                    print("📱 [PhotoScanStore] Error description: \(error.localizedDescription)")
                    print("📱 [PhotoScanStore] Will retry in 2 seconds...")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    // Don't stop polling immediately on error, maybe retry?
                    // For now, just wait and retry
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                }
            }
            
            print("[PhotoScanStore] Polling task cancelled")
            await MainActor.run {
                self.isPolling = false
                print("[PhotoScanStore] isPolling set to false")
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        isPolling = false
    }
    
    // Convert DTO.ScanProductInfo to ProductInfo for UI compatibility
    var productInfo: ProductInfo? {
        print("[PhotoScanStore] productInfo computed property accessed")
        guard let scan = scanDetails else {
            print("[PhotoScanStore] No scanDetails available, returning nil")
            return nil
        }
        
        print("[PhotoScanStore] Converting ScanProductInfo to ProductInfo...")
        print("[PhotoScanStore] Product name: \(scan.product_info.name ?? "nil")")
        print("[PhotoScanStore] Product brand: \(scan.product_info.brand ?? "nil")")
        print("[PhotoScanStore] Ingredients count: \(scan.product_info.ingredients.count)")
        print("[PhotoScanStore] Images count: \(scan.product_info.images?.count ?? 0)")
        
        // Convert ingredients from DTO.Ingredient to IngredientEntry
        let ingredientEntries: [IngredientEntry]? = scan.product_info.ingredients.isEmpty ? nil : scan.product_info.ingredients.map { ingredient in
            // Convert DTO.Ingredient to IngredientEntry
            // For now, we'll use the name as a string entry
            return .string(ingredient.name)
        }
        
        // Convert images from ScanImageInfo to ScanProductImage
        let productImages: [ScanProductImage]? = scan.product_info.images?.compactMap { imgInfo in
            guard let url = imgInfo.url else { return nil }
            return ScanProductImage(url: url)
        }
        
        let productInfo = ProductInfo(
            name: scan.product_info.name,
            brand: scan.product_info.brand,
            ingredients: ingredientEntries,
            images: productImages,
            netQuantity: nil // DTO.ScanProductInfo doesn't have netQuantity
        )
        
        print("[PhotoScanStore] ✅ Successfully converted to ProductInfo")
        return productInfo
    }
}
