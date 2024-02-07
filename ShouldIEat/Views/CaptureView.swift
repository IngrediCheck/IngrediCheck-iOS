import SwiftUI

enum Choice {
    case barcode
    case ingredients
}

struct CaptureView: View {
    
    @Binding var routes: [CapturedItem]
    @State private var selection: Choice = .barcode
    
    private var navigationTitle: String {
        switch selection {
        case .barcode:
            return "Capture Barcode"
        case .ingredients:
            return "Capture Ingredients"
        }
    }
    
    var body: some View {
        VStack {
            if selection == .barcode {
                BarcodeScannerView(routes: $routes)
            } else {
                ImageCaptureView(routes: $routes)
            }
            
            Picker("Options", selection: $selection) {
                Text("Barcode").tag(Choice.barcode)
                Text("Ingredients").tag(Choice.ingredients)
            }
            .pickerStyle(.segmented)
//                None of these approaches work to apply a tint to the picker
//                .accentColor(.paletteAccent)
//                .tint(.paletteAccent)
//                .foregroundColor(.paletteAccent)
//                .foregroundStyle(.paletteAccent)
            Spacer()
            Divider()
                .padding(.bottom)
        }
        .animation(.default, value: selection)
        .padding()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
