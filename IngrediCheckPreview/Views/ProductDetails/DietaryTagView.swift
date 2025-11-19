import SwiftUI

struct DietaryTag: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct DietaryTagView: View {
    let tag: DietaryTag
    
    var body: some View {
        HStack(spacing: 6) {
            Image(tag.icon)
                .resizable()
                .frame(width: 16, height: 16)
            
            Text(tag.name)
                .font(ManropeFont.medium.size(12))
                .foregroundStyle(.grayScale140)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(
            Color(hex: "F5F5F5"),
            in: Capsule()
        )
    }
}

