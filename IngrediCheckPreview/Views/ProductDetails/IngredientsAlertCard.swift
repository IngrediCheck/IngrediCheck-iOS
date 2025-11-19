import SwiftUI

struct IngredientsAlertCard: View {
    @Binding var isExpanded: Bool
    var items: [IngredientAlertItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            summaryText
                .padding(.horizontal, 20)
            
            if isExpanded {
                alertItemsList
            } else {
                readMoreRow(text: "Read More")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(hex: "#FFEAEA"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                
                Text("Ingredients Alerts")
                    .font(NunitoFont.bold.size(12))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color(hex: "#FF594E"), in: Capsule())
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var summaryText: some View {
        Group {
            Text("Made with ")
                .foregroundStyle(.grayScale150)
            + Text("refined flour, palm oil, and flavor enhancers")
                .foregroundStyle(Color(hex: "#FF4E50"))
                .fontWeight(.bold)
            + Text(", not ideal for your clean and heart-friendly choices.")
                .foregroundStyle(.grayScale150)
        }
        .font(ManropeFont.regular.size(14))
        .lineSpacing(6)
    }
    
    private func readMoreRow(text: String) -> some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Text(text)
                    .font(NunitoFont.bold.size(15))
                    .foregroundStyle(.grayScale150)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.grayScale150)
            }
        }
    }
    
    private var alertItemsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 12) {
                    statusChip(for: item.status)
                        .padding(.top, index == 0 ? 20 : 0)
                    
                    Text(item.name)
                        .font(NunitoFont.bold.size(16))
                        .foregroundStyle(Color.grayScale150)
                    
                    Text(item.detail)
                        .font(ManropeFont.regular.size(14))
                        .foregroundStyle(.grayScale120)
                        .lineSpacing(4)
                    
                    HStack {
                        avatarStack
                        Spacer()
                        HStack(spacing: 12) {
                            Image("thumbsup")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 24)
                                .foregroundStyle(.grayScale130)
                            
                            Image("thumbsdown")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 24)
                                .foregroundStyle(.grayScale130)
                        }
                    }
                }
                .padding(.vertical, 12)
                
                if index != items.count - 1 {
                    Divider()
                }
            }
            
            readMoreRow(text: "Read Less")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "#D8D8D8").opacity(0.25), radius: 9.8, y: 6)
        .padding(.top, 4)
    }
    
    private func statusChip(for status: IngredientAlertStatus) -> some View {
        Text(status.title)
            .font(NunitoFont.bold.size(12))
            .foregroundStyle(status.foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(status.backgroundColor, in: Capsule())
    }
    
    private var avatarStack: some View {
        HStack(spacing: -8) {
            ForEach(["image-bg1", "image-bg2", "image-bg3", "image-bg4", "image-bg5"], id: \.self) { name in
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

struct IngredientAlertItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let status: IngredientAlertStatus
}

enum IngredientAlertStatus {
    case unmatched
    case uncertain
    
    var title: String {
        switch self {
        case .unmatched: return "Unmatched"
        case .uncertain: return "Uncertain"
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .unmatched: return Color(hex: "#FF4E50")
        case .uncertain: return Color(hex: "#E9A600")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .unmatched: return Color(hex: "#FFE3E2")
        case .uncertain: return Color(hex: "#FFF4DB")
        }
    }
}

