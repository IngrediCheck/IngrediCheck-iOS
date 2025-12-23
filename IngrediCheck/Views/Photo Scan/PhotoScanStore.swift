import SwiftUI
import Combine

@MainActor
class PhotoScanStore: ObservableObject {
    @Published var scanId: String?
    @Published var scanDetails: ScanDetailsResponse?
    @Published var isUploading: Bool = false
    @Published var isPolling: Bool = false
    @Published var errorMessage: String?
    
    private var pollingTask: Task<Void, Never>?
    
    // Dependencies (injected or accessed via Environment in real app, 
    // but here we might need to pass them or use a singleton/shared instance if available)
    // For now, I'll assume we pass baseURL, apiKey, jwt to the methods or store them.
    // In the app, these usually come from AuthStore or Config.
    
    func startNewScan() {
        self.scanId = UUID().uuidString
        self.scanDetails = nil
        self.errorMessage = nil
        self.isUploading = false
        self.isPolling = false
        self.pollingTask?.cancel()
    }
    
    func uploadImage(image: UIImage, baseURL: String, apiKey: String, jwt: String) async {
        guard let scanId = scanId else {
            self.errorMessage = "No scan ID generated"
            return
        }
        
        self.isUploading = true
        self.errorMessage = nil
        
        do {
            let response = try await PhotoScanAPI.submitImage(
                baseURL: baseURL,
                apiKey: apiKey,
                jwt: jwt,
                scanId: scanId,
                image: image
            )
            
            print("Upload successful: \(response)")
            self.isUploading = false
            
            // Start polling after successful upload
            self.startPolling(baseURL: baseURL, apiKey: apiKey, jwt: jwt)
            
        } catch {
            print("Upload failed: \(error)")
            self.errorMessage = "Upload failed: \(error.localizedDescription)"
            self.isUploading = false
        }
    }
    
    func startPolling(baseURL: String, apiKey: String, jwt: String) {
        self.pollingTask?.cancel()
        self.isPolling = true
        
        self.pollingTask = Task {
            guard let scanId = self.scanId else { return }
            
            while !Task.isCancelled {
                do {
                    let details = try await PhotoScanAPI.getScanDetails(
                        baseURL: baseURL,
                        apiKey: apiKey,
                        jwt: jwt,
                        scanId: scanId
                    )
                    
                    self.scanDetails = details
                    
                    // Check if analysis is complete
                    if let status = details.analysisStatus, status == "complete" {
                        self.isPolling = false
                        return
                    }
                    
                    // Wait before next poll (e.g., 2 seconds)
                    try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    
                } catch {
                    print("Polling error: \(error)")
                    // Don't stop polling immediately on error, maybe retry?
                    // For now, just wait and retry
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                }
            }
            
            self.isPolling = false
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        isPolling = false
    }
}
