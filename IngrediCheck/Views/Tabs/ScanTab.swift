import SwiftUI

struct ProductImage: Hashable {
    let image: UIImage
    let ocrTask: Task<String, Error>
    let uploadTask: Task<String, Error>
    let barcodeDetectionTask: Task<String?, Error>
}

enum CapturedItem: Hashable {
    case barcode
    case productImages([ProductImage])
}

enum CaptureSelectionType {
    case barcode
    case ingredients
}

struct ScanTab: View {
    @State private var routes: [CapturedItem] = []
    @State private var captureSelection: CaptureSelectionType = .barcode
    @State private var barcode: String?

    var body: some View {
        NavigationStack(path: $routes) {
            VStack {
                CaptureView(routes: $routes, captureSelection: $captureSelection, barcode: $barcode)
                Divider()
                    .padding(.bottom, 5)
            }
            .navigationDestination(for: CapturedItem.self) { item in
                switch item {
                    case .productImages(let productImages):
                        LabelAnalysisView(productImages: productImages)
                    case .barcode:
                        BarcodeAnalysisView(routes: $routes, captureSelection: $captureSelection, barcode: $barcode)
                }
            }
        }
    }
}

#Preview {
    ScanTab()
}
