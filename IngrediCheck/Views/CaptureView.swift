import SwiftUI

struct CaptureView: View {
    
    @Binding var barcode: String?
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        @Bindable var appStateBindable = appState
        VStack {
            if userPreferences.captureType == .barcode {
                BarcodeScannerView(barcode: $barcode)
            } else {
                ImageCaptureView(
                    capturedImages: $appStateBindable.checkTabState.capturedImages,
                    onSubmit: {
                        appState.checkTabState.routes.append(.productImages(appState.checkTabState.capturedImages))
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
                    Text("Ingredients").tag(CaptureType.ingredients)
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
