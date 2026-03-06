import SwiftUI

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ManropeFont.medium.size(13))
                .foregroundStyle(isSelected ? .white : .grayScale100)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? LinearGradient(colors: [Color(hex: "#9DCF10"), Color(hex: "#6B8E06")], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [.white, .white], startPoint: .leading, endPoint: .trailing))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.grayScale50, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
