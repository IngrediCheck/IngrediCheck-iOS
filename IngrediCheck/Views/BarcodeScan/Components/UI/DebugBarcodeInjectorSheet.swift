#if DEBUG
import SwiftUI
import UIKit

struct DebugBarcodeInjectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isBarcodeFieldFocused: Bool
    @State private var barcode = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let onInject: (String) -> Void

    private var normalizedBarcode: String {
        barcode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("DEBUG only. This sends a typed barcode through the same path used by live camera detection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Enter barcode", text: $barcode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($isBarcodeFieldFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        injectBarcode()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )

                HStack(spacing: 12) {
                    Button("Paste Clipboard") {
                        barcode = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Inject") {
                        injectBarcode()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(normalizedBarcode.isEmpty)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Inject Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
        .onAppear {
            isBarcodeFieldFocused = true
        }
    }

    private func injectBarcode() {
        let value = normalizedBarcode
        guard !value.isEmpty else { return }
        onInject(value)
        dismiss()
    }
}
#endif
