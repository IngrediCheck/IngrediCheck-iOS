import SwiftUI

// Simple struct for dietary claims (API now includes emojis in the claim text)
struct DietaryTag: Identifiable {
    let id = UUID()
    let claim: String  // Full claim text with emoji from API (e.g., "🌾 No gluten")
}

struct DietaryTagView: View {
    let tag: DietaryTag
    
    var body: some View {
        Text(tag.claim)
            .font(ManropeFont.medium.size(14))
            .foregroundStyle(.grayScale150)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                Color(hex: "FfFfFf"),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#E9E9E9"), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Single Tag") {
    DietaryTagView(tag: DietaryTag(claim: "🌾 No gluten"))
        .padding()
}

#Preview("Multiple Tags") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            DietaryTagView(tag: DietaryTag(claim: "🌱 Vegan"))
            DietaryTagView(tag: DietaryTag(claim: "🌾 No gluten"))
            DietaryTagView(tag: DietaryTag(claim: "☕ No caffeine"))
            DietaryTagView(tag: DietaryTag(claim: "🥗 Low fat"))
        }
        .padding()
    }
}
#endif
