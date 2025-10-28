import SwiftUI
import UIKit

struct CustomSheet<Item: Identifiable, Content: View>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let cornerRadius: CGFloat
    let heightsForItem: (Item) -> (min: CGFloat, max: CGFloat)
    let content: (Item) -> Content

    init(
        item: Binding<Item?>,
        cornerRadius: CGFloat = 16,
        heightsForItem: @escaping (Item) -> (min: CGFloat, max: CGFloat),
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._item = item
        self.cornerRadius = cornerRadius
        self.heightsForItem = heightsForItem
        self.content = content
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ parent: UIViewController, context: Context) {
        guard let newItem = item else {
            // dismiss if item is nil
            if let presented = parent.presentedViewController {
                presented.dismiss(animated: true) {
                    context.coordinator.presentedID = nil
                }
            }
            return
        }

        // Skip if same sheet already visible
        if context.coordinator.presentedID == newItem.id { return }

        let presentSheet = {
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
                    let (minH, maxH) = heightsForItem(newItem)

                    let minID = UISheetPresentationController.Detent.Identifier("custom.min.\(Int(minH))")
                    let maxID = UISheetPresentationController.Detent.Identifier("custom.max.\(Int(maxH))")

                    let minDetent = UISheetPresentationController.Detent.custom(identifier: minID) { _ in minH }
                    let maxDetent = UISheetPresentationController.Detent.custom(identifier: maxID) { _ in maxH }

                    sheet.detents = [minDetent, maxDetent]
                    sheet.selectedDetentIdentifier = minID
                    sheet.largestUndimmedDetentIdentifier = maxID
                    sheet.prefersGrabberVisible = false
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                    sheet.preferredCornerRadius = cornerRadius

                    hosting.presentationController?.delegate = context.coordinator
                }
            }
        }

        // If a different sheet is open, dismiss first
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
            // reset when user dismisses by swipe
            itemBinding.wrappedValue = nil
            presentedID = nil
        }
    }
}

