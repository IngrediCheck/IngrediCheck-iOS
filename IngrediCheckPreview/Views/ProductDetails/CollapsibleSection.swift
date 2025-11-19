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
                }
                .padding(.vertical, 12)
            }
            
            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .blurReplace))
                    .padding(.bottom, 16)
            }
            
            Divider()
        }
    }
}

