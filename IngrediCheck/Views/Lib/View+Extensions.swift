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
}
