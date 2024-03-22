import SwiftUI

extension View {
    func onEnter(@Binding of text: String, action: @escaping () -> ()) -> some View {
        onChange(of: text) { oldValue, newValue in
            if let last = newValue.last, last == "\n" {
                text.removeLast()
                action()
            }
        }
    }
}
