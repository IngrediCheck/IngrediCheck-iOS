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

struct CheckTab: View {
    @State private var barcode: String?
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var appStateBinding = appState
        NavigationStack(path: $appStateBinding.checkTabState.routes) {
            VStack {
                CaptureView(barcode: $barcode)
                Spacer()
                Divider()
            }
            .navigationDestination(for: CapturedItem.self) { item in
                switch item {
                    case .productImages(let productImages):
                        LabelAnalysisView(productImages: productImages)
                    case .barcode:
                        BarcodeAnalysisView(barcode: $barcode)
                }
            }
        }
    }
}

#Preview {
    CheckTab()
}
