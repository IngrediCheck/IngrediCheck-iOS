import SwiftUI

struct CaptureView: View {
    
    @Binding var barcode: String?
    @Environment(UserPreferences.self) var userPreferences

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        VStack {
            if userPreferences.captureType == .barcode {
                BarcodeScannerView(barcode: $barcode)
            } else {
                ImageCaptureView()
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
            }
        }
    }
}
