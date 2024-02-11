import SwiftUI

struct ProductImage: Hashable {
    let image: UIImage
    let imageOCRText: String
}

enum CapturedItem: Hashable {
    case barcode(String)
    case productImages([ProductImage])
}

struct ScanTab: View {
    @State private var routes: [CapturedItem] = []
    @State private var analysis: String?
    @State private var errorExtractingIngredientsList: Bool = false

    var body: some View {
        NavigationStack(path: $routes) {
            VStack {
                CaptureView(routes: $routes)
                Divider()
                    .padding(.bottom, 5)
            }
            .navigationDestination(for: CapturedItem.self) { item in
                switch item {
                    case .productImages(let productImages):
                        LabelAnalysisView(productImages: productImages)
                    case .barcode(let barcode):
                        BarcodeAnalysisView(barcode: barcode)
                }
            }
        }
    }
}

#Preview {
    ScanTab()
}
