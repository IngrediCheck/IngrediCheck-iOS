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
    
    @Binding var barcode: String?
    @State private var dataScannerAccessStatus: DataScannerAccessStatusType = .notDetermined
    @State private var showScanner = true

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
        return DataScannerView(routes: $checkTabState.routes, barcode: $barcode)
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.paletteSecondary, lineWidth: 0.8)
            )
            .padding(.top)
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
    @Binding var barcode: String?

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
        return Coordinator(routes: $routes, barcode: $barcode)
    }
    
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        //
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        
        @Binding var routes: [CapturedItem]
        @Binding var barcode: String?

        init(routes: Binding<[CapturedItem]>, barcode: Binding<String?>) {
            self._routes = routes
            self._barcode = barcode
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if let firstItem = addedItems.first,
               case let .barcode(barcodeItem) = firstItem,
               let barcodeString = barcodeItem.payloadStringValue {
                self.barcode = barcodeString
                self.routes.append(.barcode)
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
