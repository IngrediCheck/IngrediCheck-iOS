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
        // If sheet should close
        guard let newItem = item else {
            if let presented = parent.presentedViewController {
                presented.dismiss(animated: true) {
                    context.coordinator.presentedID = nil
                }
            }
            return
        }

        // If same sheet already showing, skip
        if context.coordinator.presentedID == newItem.id { return }

        let presentSheet = {
            // Build hosting controller
            let hosting = UIHostingController(rootView:
                ZStack {
                    Color.white.ignoresSafeArea()
                    content(newItem)
                }
            )
            hosting.view.backgroundColor = .white
            hosting.modalPresentationStyle = .pageSheet

            parent.present(hosting, animated: true)
            context.coordinator.presentedID = newItem.id

            DispatchQueue.main.async {
                if let sheet = hosting.sheetPresentationController {
                    let h = heightForItem(newItem)
                    let id = UISheetPresentationController.Detent.Identifier("custom.\(Int(h))")
                    let detent = UISheetPresentationController.Detent.custom(identifier: id) { _ in h }
                    sheet.detents = [detent]
                    sheet.largestUndimmedDetentIdentifier = id
                    sheet.prefersGrabberVisible = true
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                    sheet.preferredCornerRadius = cornerRadius
                    hosting.presentationController?.delegate = context.coordinator
                }
            }
        }

        // If another sheet is still visible → dismiss first, then present the new one
        if parent.presentedViewController != nil {
            parent.presentedViewController?.dismiss(animated: true) {
                context.coordinator.presentedID = nil
                presentSheet()
            }
        } else {
            presentSheet()
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
            // Reset binding when user swipes down to dismiss
            itemBinding.wrappedValue = nil
            presentedID = nil
        }
    }
}

