import SwiftUI

struct CaptureView: View {
    
    @Environment(UserPreferences.self) var userPreferences
    @Environment(CheckTabState.self) var checkTabState
    @Environment(WebService.self) var webService
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @State private var barcodeScanController: BarcodeScanController?

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        @Bindable var checkTabState = checkTabState
        VStack {
            if userPreferences.captureType == .barcode {
                if let scanController = barcodeScanController {
                    BarcodeScannerView(scanController: scanController)
                } else {
                    ProgressView()
                }
            } else {
                ImageCaptureView(
                    capturedImages: $checkTabState.capturedImages,
                    onSubmit: {
                        // Navigate to LabelAnalysisView with scanId
                        if let scanId = checkTabState.scanId {
                            checkTabState.routes.append(.productImages(scanId))
                        }
                    },
                    showClearButton: true,
                    showTitle: false,
                    showCancelButton: false
                )
            }
        }
        .animation(.default, value: userPreferences.captureType)
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if barcodeScanController == nil {
                barcodeScanController = BarcodeScanController(
                    checkTabState: checkTabState,
                    webService: webService,
                    dietaryPreferences: dietaryPreferences,
                    userPreferences: userPreferences
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Options", selection: $userPreferencesBindable.captureType) {
                    Text("Barcode").tag(CaptureType.barcode)
                    Text("Photo").tag(CaptureType.ingredients)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onAppear {
                    UISegmentedControl.appearance().selectedSegmentTintColor = .paletteAccent
                }
            }
        }
    }
}
