import SwiftUI

enum Choice {
    case barcode
    case ingredients
}

struct CaptureView: View {
    
    @Binding var image: UIImage?
    @Binding var imageOCRText: String?
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
        NavigationStack {
            VStack {
                if selection == .barcode {
                    Spacer()
                } else {
                    ImageCaptureView(image: $image, imageOCRText: $imageOCRText)
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
                .padding()
            }
            .animation(.default, value: selection)
            .padding()
            .navigationBarItems(trailing: CloseButton())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
