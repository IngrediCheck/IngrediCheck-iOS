import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(ManropeFont.semiBold.size(16))
                        .foregroundStyle(.grayScale150)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.grayScale100)
                        .contentTransition(.symbolEffect(.replace))
                }
            }

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .blurReplace))
                    .padding(.top, 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(lineWidth: 2)
                        .foregroundStyle(Color(hex: "#EEEEEE"))
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

