import SwiftUI

struct ProductImage: Hashable {
    let image: UIImage
    let ocrTask: Task<String, Error>
    let uploadTask: Task<String, Error>
    let barcodeDetectionTask: Task<String?, Error>
}

enum CapturedItem: Hashable {
    case barcode(String)
    case productImages([ProductImage])
}

struct CheckTab: View {
    @State private var checkTabState = CheckTabState()

    var body: some View {
        NavigationStack(path: $checkTabState.routes) {
            VStack {
                CaptureView()
                Spacer()
            }
            .sheet(item: $checkTabState.feedbackConfig) { feedbackConfig in
                let _ = print("Activating feedback sheet")
                FeedbackView(
                    feedbackData: feedbackConfig.feedbackData,
                    feedbackCaptureOptions: feedbackConfig.feedbackCaptureOptions,
                    onSubmit: feedbackConfig.onSubmit
                )
            }
            .environment(checkTabState)
            .navigationDestination(for: CapturedItem.self) { item in
                switch item {
                    case .productImages(let productImages):
                        LabelAnalysisView(productImages: productImages)
                            .environment(checkTabState)
                    case .barcode(let barcode):
                        BarcodeAnalysisView(barcode: barcode)
                            .environment(checkTabState)
                }
            }
        }
    }
}

#Preview {
    CheckTab()
}
