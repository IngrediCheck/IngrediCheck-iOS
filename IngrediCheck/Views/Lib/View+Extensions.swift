import SwiftUI

extension View {
    func onEnter(@Binding of text: String, isFocused: FocusState<Bool>.Binding, action: @escaping () -> ()) -> some View {
        onChange(of: text) { oldValue, newValue in
            if let last = newValue.last, last == "\n" {
                text.removeLast()
                isFocused.wrappedValue = false
                action()
            }
        }
    }

    func dismissKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}
