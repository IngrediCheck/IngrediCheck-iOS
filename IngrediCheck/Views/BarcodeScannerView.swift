import AVKit
import Foundation
import SwiftUI
import VisionKit
import PostHog
import os

enum DataScannerAccessStatusType {
    case notDetermined
    case cameraAccessNotGranted
    case cameraNotAvailable
    case scannerAvailable
    case scannerNotAvailable
}

var startTime = Date().timeIntervalSince1970

@MainActor
@Observable final class BarcodeScanController {

    private let checkTabState: CheckTabState
    private let webService: WebService
    private let dietaryPreferences: DietaryPreferences
    private let userPreferences: UserPreferences

    var showSuccessOverlay = false
    var detectedBarcodeBounds: CGRect = .zero

    private var pendingNavigationTask: Task<Void, Never>?
    private var activeAnalysisTask: Task<Void, Never>?
    private var isProcessingBarcode = false
    private let successFeedbackGenerator = UINotificationFeedbackGenerator()

    init(
        checkTabState: CheckTabState,
        webService: WebService,
        dietaryPreferences: DietaryPreferences,
        userPreferences: UserPreferences
    ) {
        self.checkTabState = checkTabState
        self.webService = webService
        self.dietaryPreferences = dietaryPreferences
        self.userPreferences = userPreferences
        successFeedbackGenerator.prepare()
    }

    func handleScan(barcodeString: String, viewBounds: CGRect) {
        guard !isProcessingBarcode else {
            return
        }

        if case let .some(.barcode(lastBarcode)) = checkTabState.routes.last,
           lastBarcode.barcode == barcodeString {
            return
        }

        isProcessingBarcode = true

        pendingNavigationTask?.cancel()
        pendingNavigationTask = nil

        let centerX = viewBounds.width / 2
        let centerY = viewBounds.height / 2
        detectedBarcodeBounds = CGRect(
            x: centerX - 100,
            y: centerY - 50,
            width: 200,
            height: 100
        )

        showSuccessOverlay = true
        successFeedbackGenerator.notificationOccurred(.success)

        let viewModel = BarcodeAnalysisViewModel(
            barcodeString,
            webService,
            dietaryPreferences,
            userPreferences
        )

        activeAnalysisTask = Task {
            await viewModel.analyze()
        }

        pendingNavigationTask = Task { [weak self, viewModel] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.isProcessingBarcode else {
                        self.activeAnalysisTask?.cancel()
                        return
                    }

                    let capturedBarcode = CapturedBarcode(barcode: barcodeString, viewModel: viewModel)
                    self.checkTabState.routes.append(.barcode(capturedBarcode))
                    self.showSuccessOverlay = false
                    self.isProcessingBarcode = false
                    self.pendingNavigationTask = nil
                }
            } catch {
                await MainActor.run {
                    self.activeAnalysisTask?.cancel()
                    self.isProcessingBarcode = false
                    self.showSuccessOverlay = false
                    self.pendingNavigationTask = nil
                }
            }
        }

        PostHogSDK.shared.capture("Barcode Scanning Completed", properties: [
            "latency_ms": (Date().timeIntervalSince1970 * 1000) - (startTime * 1000),
            "barcode_number": barcodeString
        ])
    }

    func cancelPendingOperations() {
        pendingNavigationTask?.cancel()
        pendingNavigationTask = nil
        
        if isProcessingBarcode {
            activeAnalysisTask?.cancel()
            isProcessingBarcode = false
        }
        
        showSuccessOverlay = false
        detectedBarcodeBounds = .zero
    }
}

@MainActor struct BarcodeScannerView: View {
    
    @State private var dataScannerAccessStatus: DataScannerAccessStatusType = .notDetermined
    @State private var showScanner = true
    let scanController: BarcodeScanController

    init(scanController: BarcodeScanController) {
        self.scanController = scanController
    }

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
        DataScannerView(scanController: scanController)
        .aspectRatio(3/4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.paletteSecondary, lineWidth: 0.8)
                if scanController.showSuccessOverlay {
                    BarcodeSuccessOverlay(bounds: scanController.detectedBarcodeBounds)
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
    
    let scanController: BarcodeScanController

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let uiViewController = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8 ,.code128, .code39, .code93, .upce])],
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
        Coordinator(scanController: scanController)
    }
    
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        coordinator.scanController.cancelPendingOperations()
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        
        let scanController: BarcodeScanController
        
        init(scanController: BarcodeScanController) {
            self.scanController = scanController
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let firstItem = addedItems.first,
                  case let .barcode(barcodeItem) = firstItem,
                  let barcodeString = barcodeItem.payloadStringValue else {
                return
            }
            
            let viewBounds = dataScanner.view.bounds
            scanController.handleScan(
                barcodeString: barcodeString,
                viewBounds: viewBounds
            )
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
//            Log.debug("BarcodeScannerView", "dataScanner: didRemove")
//            print(removedItems)
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            Log.error("BarcodeScannerView", "became unavailable with error \(error.localizedDescription)")
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
