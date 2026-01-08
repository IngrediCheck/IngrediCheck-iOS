import SwiftUI

struct ProductImage: Hashable {
    let image: UIImage
}

struct CapturedBarcode: Hashable {
    let id: UUID
    let barcode: String
    let viewModel: BarcodeAnalysisViewModel

    init(barcode: String, viewModel: BarcodeAnalysisViewModel, id: UUID = UUID()) {
        self.id = id
        self.barcode = barcode
        self.viewModel = viewModel
    }

    static func == (lhs: CapturedBarcode, rhs: CapturedBarcode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum CapturedItem: Hashable {
    case barcode(CapturedBarcode)
    case productImages(String)  // scanId for photo scans
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
                    case .productImages(let scanId):
                        LabelAnalysisView(scanId: scanId)
                            .environment(checkTabState)
                    case .barcode(let capturedBarcode):
                        BarcodeAnalysisView(barcode: capturedBarcode.barcode, viewModel: capturedBarcode.viewModel)
                            .environment(checkTabState)
                }
            }
        }
    }
}

#Preview {
    CheckTab()
}
