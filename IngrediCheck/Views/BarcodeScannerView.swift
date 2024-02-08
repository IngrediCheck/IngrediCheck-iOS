import AVKit
import Foundation
import SwiftUI
import VisionKit

enum DataScannerAccessStatusType {
    case notDetermined
    case cameraAccessNotGranted
    case cameraNotAvailable
    case scannerAvailable
    case scannerNotAvailable
}

@MainActor struct BarcodeScannerView: View {
    
    @Binding var routes: [CapturedItem]
    @State private var dataScannerAccessStatus: DataScannerAccessStatusType = .notDetermined
    @State private var showScanner = true

    var body: some View {
        VStack {
            switch dataScannerAccessStatus {
            case .scannerAvailable:
                // Workaround: Dismantle DataScannerViewController when navigating away from this view.
                // This is because the following sequence of actions results in freeze of scanning:
                // startScanning => stopScanning() => startScanning().
                if showScanner {
                    mainView
                }
            case .cameraNotAvailable:
                Text("Your device doesn't have a camera")
            case .scannerNotAvailable:
                Text("Your device doesn't have support for scanning barcode with this app")
            case .cameraAccessNotGranted:
                Text("Please provide access to the camera in settings")
            case .notDetermined:
                Text("Requesting camera access")
            }
            Spacer()
        }
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
        DataScannerView(routes: $routes)
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.paletteSecondary, lineWidth: 0.8)
            )
    }
    
    private var isScannerAvailable: Bool {
        DataScannerViewController.isAvailable
        &&
        DataScannerViewController.isSupported
    }

    func requestDataScannerAccessStatus() async {
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

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let uiViewController = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
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
        return Coordinator(routes: $routes)
    }
    
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        //
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        
        @Binding var routes: [CapturedItem]

        init(routes: Binding<[CapturedItem]>) {
            self._routes = routes
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if let firstItem = addedItems.first,
               case let .barcode(barcodeItem) = firstItem,
               let barcodeString = barcodeItem.payloadStringValue {
                self.routes.append(.barcode(barcodeString))
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
