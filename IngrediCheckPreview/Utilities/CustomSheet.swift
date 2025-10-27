import SwiftUI
import UIKit

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
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ parent: UIViewController, context: Context) {
        guard let item = item else {
            // dismiss if nil
            if let presented = parent.presentedViewController {
                presented.dismiss(animated: true) {
                    // reset so same item can be re-presented later
                    context.coordinator.presentedID = nil
                }
            }
            return
        }

        // if same sheet already showing, skip
        if context.coordinator.presentedID == item.id { return }

        // create a hosting controller for the sheet
        let hosting = UIHostingController(rootView:
            ZStack {
                Color.white.ignoresSafeArea() // full white background
                content(item)
            }
        )

        hosting.view.backgroundColor = .white
        hosting.modalPresentationStyle = .pageSheet

        parent.present(hosting, animated: true)
        context.coordinator.presentedID = item.id

        DispatchQueue.main.async {
            if let sheet = hosting.sheetPresentationController {
                let h = heightForItem(item)

                let identifier = UISheetPresentationController.Detent.Identifier("custom.\(Int(h))")
                let detent = UISheetPresentationController.Detent.custom(identifier: identifier) { _ in h }
                sheet.detents = [detent]
                sheet.largestUndimmedDetentIdentifier = identifier // remove dimming
                sheet.prefersGrabberVisible = false
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                sheet.preferredCornerRadius = cornerRadius

                // when sheet is dismissed by swipe or drag down, reset coordinator
                hosting.presentationController?.delegate = context.coordinator
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(itemBinding: _item)
    }

    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var presentedID: Item.ID?
        private var itemBinding: Binding<Item?>

        init(itemBinding: Binding<Item?>) {
            self.itemBinding = itemBinding
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // update SwiftUI binding to nil when dismissed by swipe
            itemBinding.wrappedValue = nil
            presentedID = nil
        }
    }
}

