import SwiftUI

enum Choice {
    case barcode
    case ingredients
}

struct CaptureView: View {
    
    @Binding var routes: [CapturedItem]
    @State private var selection: Choice = .barcode

    var body: some View {
        VStack {
            if selection == .barcode {
                BarcodeScannerView(routes: $routes)
            } else {
                ImageCaptureView(routes: $routes)
            }
        }
        .animation(.default, value: selection)
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Options", selection: $selection) {
                    Text("Barcode").tag(Choice.barcode)
                    Text("Ingredients").tag(Choice.ingredients)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onAppear {
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.paletteAccent], for: .normal)
                }
            }
        }
    }
}
