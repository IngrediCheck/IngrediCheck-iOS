import SwiftUI

struct CaptureView: View {
    
    @Binding var barcode: String?
    @Environment(UserPreferences.self) var userPreferences
    @Environment(CheckTabState.self) var checkTabState

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        @Bindable var checkTabState = checkTabState
        VStack {
            if userPreferences.captureType == .barcode {
                BarcodeScannerView(barcode: $barcode)
            } else {
                ImageCaptureView(
                    capturedImages: $checkTabState.capturedImages,
                    onSubmit: {
                        checkTabState.routes.append(.productImages(checkTabState.capturedImages))
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
