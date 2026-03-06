import SwiftUI

struct InventoryProductCard: View {
    let product: MockInventoryProduct
    let matchStatus: DTO.ProductRecommendation

    var body: some View {
        HStack(spacing: 12) {
            // Product image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.grayScale30)
                    .frame(width: 82, height: 98)
                Image(systemName: product.category.sfSymbol)
                    .font(.system(size: 28))
                    .foregroundStyle(.grayScale80)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(ManropeFont.bold.size(16))
                        .foregroundStyle(.teritairy1000)
                        .lineLimit(2)

                    Text(product.brand)
                        .font(ManropeFont.regular.size(12))
                        .foregroundStyle(.grayScale100)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Category + match status row
                HStack(spacing: 8) {
                    // Match status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(matchStatus.badgeDotColor)
                            .frame(width: 8, height: 8)
                        Text(matchStatus.displayText)
                            .font(ManropeFont.semiBold.size(12))
                            .foregroundStyle(matchStatus.badgeTextColor)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(matchStatus.badgeBackgroundColor)
                    )

                    // Category chip
                    Text(product.category.rawValue)
                        .font(ManropeFont.regular.size(11))
                        .foregroundStyle(.grayScale80)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.grayScale30)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#EEEEEE"), lineWidth: 1)
        )
    }
}
