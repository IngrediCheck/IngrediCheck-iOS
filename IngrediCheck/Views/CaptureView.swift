import SwiftUI

struct CaptureView: View {
    
    @Binding var captureSelection: CaptureSelectionType
    @Binding var barcode: String?

    var body: some View {
        VStack {
            if captureSelection == .barcode {
                BarcodeScannerView(barcode: $barcode)
            } else {
                ImageCaptureView()
            }
        }
        .animation(.default, value: captureSelection)
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Options", selection: $captureSelection) {
                    Text("Barcode").tag(CaptureSelectionType.barcode)
                    Text("Ingredients").tag(CaptureSelectionType.ingredients)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }
}
