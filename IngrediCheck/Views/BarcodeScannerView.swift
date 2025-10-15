import AVKit
import Foundation
import SwiftUI
import VisionKit
import PostHog

enum DataScannerAccessStatusType {
    case notDetermined
    case cameraAccessNotGranted
    case cameraNotAvailable
    case scannerAvailable
    case scannerNotAvailable
}

var startTime = Date().timeIntervalSince1970

@MainActor struct BarcodeScannerView: View {
    
    @State private var dataScannerAccessStatus: DataScannerAccessStatusType = .notDetermined
    @State private var showScanner = true
    @State private var showSuccessOverlay = false
    @State private var detectedBarcodeBounds: CGRect = .zero

    @Environment(CheckTabState.self) var checkTabState

    var body: some View {
        VStack(spacing: 0) {
            switch dataScannerAccessStatus {
            case .scannerAvailable:
                // Workaround: Dismantle DataScannerViewController when navigating away from this view.
                // This is because the following sequence of actions results in freeze of scanning:
                // startScanning => stopScanning() => startScanning().
                if showScanner {
                    mainView
                    Text("Scan Barcode of a Packaged Food Item.")
                        .padding(.top)
                    Spacer()
                }
            case .cameraNotAvailable:
                Text("Your device doesn't have a camera")
            case .scannerNotAvailable:
                Text("Your device doesn't have support for scanning barcode with this app")
            case .cameraAccessNotGranted:
                Text("Please provide access to the camera in settings")
            case .notDetermined:
                ProgressView()
            }
        }
        .navigationBarItems(
            leading:
                Button("Cancel") {
                    //
                }
                .disabled(true)
                .foregroundStyle(.clear),
            trailing:
                Button("Done") {
                    //
                }.disabled(true)
                .foregroundStyle(.clear)
        )
        .task {
            await requestDataScannerAccessStatus()
        }
        .onAppear {
            showScanner = true
        }
        .onDisappear {
            showScanner = false
        }
    }
    
    private var mainView: some View {
        @Bindable var checkTabState = checkTabState
        return DataScannerView(
            routes: $checkTabState.routes,
            showSuccessOverlay: $showSuccessOverlay,
            detectedBarcodeBounds: $detectedBarcodeBounds
        )
        .aspectRatio(3/4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.paletteSecondary, lineWidth: 0.8)
                if showSuccessOverlay {
                    BarcodeSuccessOverlay(bounds: detectedBarcodeBounds)
                }
            }
        )
        .padding(.top)
    }
    
    private var isScannerAvailable: Bool {
        DataScannerViewController.isAvailable
        &&
        DataScannerViewController.isSupported
    }

    func requestDataScannerAccessStatus() async {
        
        startTime = Date().timeIntervalSince1970
        
        PostHogSDK.shared.capture("Barcode Started Scanning", properties: [
            "start_time": Date().timeIntervalSince1970
        ])
        
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            dataScannerAccessStatus = .cameraNotAvailable
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            
        case .authorized:
            dataScannerAccessStatus = isScannerAvailable ? .scannerAvailable : .scannerNotAvailable
            
        case .restricted, .denied:
            dataScannerAccessStatus = .cameraAccessNotGranted
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                dataScannerAccessStatus = isScannerAvailable ? .scannerAvailable : .scannerNotAvailable
            } else {
                dataScannerAccessStatus = .cameraAccessNotGranted
            }
        
        default: break
            
        }
    }
}

@MainActor
struct DataScannerView: UIViewControllerRepresentable {
    
    @Binding var routes: [CapturedItem]
    @Binding var showSuccessOverlay: Bool
    @Binding var detectedBarcodeBounds: CGRect

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let uiViewController = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        uiViewController.delegate = context.coordinator
        try? uiViewController.startScanning()
        return uiViewController
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        //
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(
            routes: $routes,
            showSuccessOverlay: $showSuccessOverlay,
            detectedBarcodeBounds: $detectedBarcodeBounds
        )
    }
    
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        //
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        
        @Binding var routes: [CapturedItem]
        @Binding var showSuccessOverlay: Bool
        @Binding var detectedBarcodeBounds: CGRect

        init(routes: Binding<[CapturedItem]>, showSuccessOverlay: Binding<Bool>, detectedBarcodeBounds: Binding<CGRect>) {
            self._routes = routes
            self._showSuccessOverlay = showSuccessOverlay
            self._detectedBarcodeBounds = detectedBarcodeBounds
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            if let firstItem = addedItems.first,
               case let .barcode(barcodeItem) = firstItem,
               let barcodeString = barcodeItem.payloadStringValue {
                // Check if we're already showing the overlay for this barcode
                if showSuccessOverlay {
                    return
                }
                
                if case .barcode(let lastBarcode) = routes.last, lastBarcode == barcodeString {
                    return
                }
                
                // Capture barcode bounds for visual feedback
                // For now, use a default centered rectangle as fallback
                // TODO: Implement proper bounds detection when VisionKit API is clarified
                let viewBounds = dataScanner.view.bounds
                let centerX = viewBounds.width / 2
                let centerY = viewBounds.height / 2
                let bounds = CGRect(
                    x: centerX - 100, // 200pt wide rectangle
                    y: centerY - 50,  // 100pt tall rectangle
                    width: 200,
                    height: 100
                )
                detectedBarcodeBounds = bounds
                
                // Show success overlay with animation
                showSuccessOverlay = true
                
                // Haptic feedback
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                // Add delay before navigation to show visual feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.routes.append(.barcode(barcodeString))
                    self.showSuccessOverlay = false
                }

                PostHogSDK.shared.capture("Barcode Scanning Completed", properties: [
                    "latency_ms": (Date().timeIntervalSince1970 * 1000) - (startTime * 1000),
                    "barcode_number": barcodeString
                ])
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
//            print("dataScanner: didRemove")
//            print(removedItems)
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            print("became unavailable with error \(error.localizedDescription)")
        }
        
    }
    
}

// MARK: - Barcode Success Overlay

struct BarcodeSuccessOverlay: View {
    let bounds: CGRect
    
    var body: some View {
        ZStack {
            // Semi-transparent blue overlay over barcode area
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: bounds.width, height: bounds.height)
                .position(
                    x: bounds.midX,
                    y: bounds.midY
                )
                .animation(.easeInOut(duration: 0.3), value: bounds)
            
            // Success checkmark in center of overlay
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .position(
                    x: bounds.midX,
                    y: bounds.midY
                )
                .scaleEffect(1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: bounds)
        }
        .allowsHitTesting(false) // Allow touches to pass through
    }
}
