import SwiftUI
import UIKit

// MARK: - CustomSheet

struct CustomSheet<Item: Identifiable, Content: View>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let cornerRadius: CGFloat
    let heightForItem: (Item) -> CGFloat
    let content: (Item) -> Content

    init(
        item: Binding<Item?>,
        cornerRadius: CGFloat = 16,
        heightForItem: @escaping (Item) -> CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._item = item
        self.cornerRadius = cornerRadius
        self.heightForItem = heightForItem
        self.content = content
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear // background of the presenting controller
        return vc
    }

    func updateUIViewController(_ parent: UIViewController, context: Context) {
        guard let item = item else {
            // dismiss if nil
            if let presented = parent.presentedViewController {
                presented.dismiss(animated: true)
            }
            return
        }

        // if same sheet already showing, skip
        if context.coordinator.presentedID == item.id { return }

        // create a hosting controller for the sheet
        let hosting = UIHostingController(rootView:
            ZStack {
                Color.white // <- makes background white
                    .ignoresSafeArea()
                content(item)
            }
        )

        hosting.view.backgroundColor = .white // <- ensures UIKit background is white
        hosting.modalPresentationStyle = .pageSheet

        parent.present(hosting, animated: true)
        context.coordinator.presentedID = item.id

        DispatchQueue.main.async {
            if let sheet = hosting.sheetPresentationController {
                let h = heightForItem(item)

                // custom detent height
                let identifier = UISheetPresentationController.Detent.Identifier("custom.\(Int(h))")
                let detent = UISheetPresentationController.Detent.custom(identifier: identifier) { _ in h }
                sheet.detents = [detent]
                sheet.largestUndimmedDetentIdentifier = identifier // removes background dimming
                sheet.prefersGrabberVisible = false
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                sheet.preferredCornerRadius = cornerRadius
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var presentedID: Item.ID?
    }
}

