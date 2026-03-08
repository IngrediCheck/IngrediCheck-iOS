#if DEBUG
import SwiftUI
import UIKit

struct DebugBarcodeInjectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isBarcodeFieldFocused: Bool
    @State private var barcode = ""

    let onInject: (String) -> Void

    private var normalizedBarcode: String {
        barcode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelyBarcode(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (8...20).contains(trimmed.count) else { return false }
        return trimmed.allSatisfy(\.isNumber)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("DEBUG only. This sends a typed barcode through the same path used by live camera detection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !DebugScanQAMode.presets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sample barcodes")
                            .font(.headline)

                        ForEach(DebugScanQAMode.presets) { preset in
                            Button {
                                barcode = preset.barcode
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.label)
                                            .foregroundStyle(.primary)
                                        Text(preset.barcode)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

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
                        let clipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        barcode = Self.isLikelyBarcode(clipboard) ? clipboard : ""
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
        .presentationDetents([.medium])
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
