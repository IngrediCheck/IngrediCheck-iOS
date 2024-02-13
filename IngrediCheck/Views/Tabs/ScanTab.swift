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
    @State private var captureSelection: CaptureSelectionType = .barcode
    @State private var barcode: String?
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var appStateBinding = appState
        NavigationStack(path: $appStateBinding.scanRoutes) {
            VStack {
                CaptureView(captureSelection: $captureSelection, barcode: $barcode)
                Divider()
                    .padding(.bottom, 5)
            }
            .navigationDestination(for: CapturedItem.self) { item in
                switch item {
                    case .productImages(let productImages):
                        LabelAnalysisView(productImages: productImages)
                    case .barcode:
                        BarcodeAnalysisView(captureSelection: $captureSelection, barcode: $barcode)
                }
            }
        }
    }
    
    var scanRoutes: Binding<[CapturedItem]> {
        return .init {
            return appState.scanRoutes
        } set: { newValue in
            
        }
    }
}

#Preview {
    ScanTab()
}
