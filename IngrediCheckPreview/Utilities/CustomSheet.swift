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


// MARK: - Boolean-based variant with same behavior

struct CustomBoolSheet<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let cornerRadius: CGFloat
    let heightsProvider: () -> (min: CGFloat, max: CGFloat)
    let content: () -> Content

    init(
        isPresented: Binding<Bool>,
        cornerRadius: CGFloat = 16,
        heights: @escaping () -> (min: CGFloat, max: CGFloat),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.cornerRadius = cornerRadius
        self.heightsProvider = heights
        self.content = content
    }

    init(
        isPresented: Binding<Bool>,
        cornerRadius: CGFloat = 16,
        heights: (min: CGFloat, max: CGFloat),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.cornerRadius = cornerRadius
        self.heightsProvider = { heights }
        self.content = content
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ parent: UIViewController, context: Context) {
        // Dismiss when toggled off
        if !isPresented {
            if let presented = parent.presentedViewController {
                presented.dismiss(animated: true) {
                    context.coordinator.isPresenting = false
                }
            }
            return
        }

        // Skip if already visible
        if context.coordinator.isPresenting { return }

        let presentSheet = {
            let hosting = UIHostingController(rootView:
                ZStack {
                    Color.white.ignoresSafeArea()
                    content()
                }
            )
            hosting.view.backgroundColor = .white
            hosting.modalPresentationStyle = .pageSheet

            parent.present(hosting, animated: true)
            context.coordinator.isPresenting = true

            DispatchQueue.main.async {
                if let sheet = hosting.sheetPresentationController {
                    let (minH, maxH) = heightsProvider()

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
                context.coordinator.isPresenting = false
                presentSheet()
            }
        } else {
            presentSheet()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: _isPresented)
    }

    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isPresenting: Bool = false
        private var isPresented: Binding<Bool>

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // reset when user dismisses by swipe
            isPresented.wrappedValue = false
            isPresenting = false
        }
    }
}

