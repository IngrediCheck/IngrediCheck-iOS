import SwiftUI

struct FeedbackButton: View {
    enum FeedbackType {
        case up
        case down
    }
    
    enum Style {
        /// Product Status style: Boxed with stroke that changes color
        case boxed
        /// Ingredients style: Plain icon, no background
        case plain
        /// Full Screen Viewer style: Circular dark background, white unselected icon
        case overlay
        /// White filled background with gray icons
        case whiteBoxed
    }
    
    let type: FeedbackType
    let isSelected: Bool
    var style: Style = .plain
    let action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isAnimating = false
                }
            }
        }) {
            content
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var content: some View {
        switch style {
        case .boxed:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(strokeColor, lineWidth: 0.5)
                
                iconView
                    .frame(width: 20, height: 18)
            }
            .frame(width: 32, height: 28)
            
        case .plain:
            iconView
                .frame(width: 28, height: 24)
                
        case .overlay:
            iconView
                .frame(width: 22, height: 22)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
            
        case .whiteBoxed:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                
                iconView
                    .frame(width: 20, height: 18)
            }
            .frame(width: 32, height: 28)
        }
    }
    
    private var iconView: some View {
        Image(assetName)
            .renderingMode(isSelected ? .original : .template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(iconColor)
            .rotationEffect(.degrees(rotationAmount))
            .offset(y: offsetAmount)
    }
    
    // MARK: - Animation Logic
    
    private var rotationAmount: Double {
        guard isAnimating else { return 0 }
        switch type {
        case .up: return -20
        case .down: return 20
        }
    }
    
    private var offsetAmount: CGFloat {
        guard isAnimating else { return 0 }
        switch type {
        case .up: return -4
        case .down: return 4
        }
    }
    
    // MARK: - Asset & Color Logic
    
    private var assetName: String {
        switch type {
        case .up: return isSelected ? "thumbsup.fill" : "thumbsup"
        case .down: return isSelected ? "thumbsdown.fill" : "thumbsdown"
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            switch type {
            case .up: return .green
            case .down: return .red
            }
        }
        
        switch style {
        case .boxed: return .grayScale100
        case .plain: return .grayScale130
        case .overlay: return .white
        case .whiteBoxed: return .grayScale100
        }
    }
    
    private var strokeColor: Color {
        guard style == .boxed else { return .clear }
        
        if isSelected {
            switch type {
            case .up: return Color(hex: "#FBCB7F") // Light orange
            case .down: return Color(hex: "#FF594E") // Light red
            }
        }
        return .grayScale100
    }
}

#Preview("FeedbackButton Styles") {
    VStack(spacing: 40) {
        // Boxed style
        VStack(spacing: 16) {
            Text("Boxed Style")
                .font(NunitoFont.bold.size(18))
                .foregroundStyle(.grayScale150)
            
            HStack(spacing: 16) {
                FeedbackButton(type: .up, isSelected: false, style: .boxed) {
                    print("Thumbs up (unselected)")
                }
                FeedbackButton(type: .up, isSelected: true, style: .boxed) {
                    print("Thumbs up (selected)")
                }
                FeedbackButton(type: .down, isSelected: false, style: .boxed) {
                    print("Thumbs down (unselected)")
                }
                FeedbackButton(type: .down, isSelected: true, style: .boxed) {
                    print("Thumbs down (selected)")
                }
            }
        }
        
        // Plain style
        VStack(spacing: 16) {
            Text("Plain Style")
                .font(NunitoFont.bold.size(18))
                .foregroundStyle(.grayScale150)
            
            HStack(spacing: 16) {
                FeedbackButton(type: .up, isSelected: false, style: .plain) {
                    print("Thumbs up (unselected)")
                }
                FeedbackButton(type: .up, isSelected: true, style: .plain) {
                    print("Thumbs up (selected)")
                }
                FeedbackButton(type: .down, isSelected: false, style: .plain) {
                    print("Thumbs down (unselected)")
                }
                FeedbackButton(type: .down, isSelected: true, style: .plain) {
                    print("Thumbs down (selected)")
                }
            }
        }
        
        // Overlay style
        VStack(spacing: 16) {
            Text("Overlay Style")
                .font(NunitoFont.bold.size(18))
                .foregroundStyle(.grayScale150)
            
            ZStack {
                Color.gray.opacity(0.3)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                
                HStack(spacing: 16) {
                    FeedbackButton(type: .up, isSelected: false, style: .overlay) {
                        print("Thumbs up (unselected)")
                    }
                    FeedbackButton(type: .up, isSelected: true, style: .overlay) {
                        print("Thumbs up (selected)")
                    }
                    FeedbackButton(type: .down, isSelected: false, style: .overlay) {
                        print("Thumbs down (unselected)")
                    }
                    FeedbackButton(type: .down, isSelected: true, style: .overlay) {
                        print("Thumbs down (selected)")
                    }
                }
            }
        }
        
        // White Boxed style
        VStack(spacing: 16) {
            Text("White Boxed Style")
                .font(NunitoFont.bold.size(18))
                .foregroundStyle(.grayScale150)
            
            ZStack {
                Color(hex: "#FFE5E5") // Light pink background like in the image
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                
                HStack(spacing: 16) {
                    FeedbackButton(type: .up, isSelected: false, style: .whiteBoxed) {
                        print("Thumbs up (unselected)")
                    }
                    FeedbackButton(type: .down, isSelected: false, style: .whiteBoxed) {
                        print("Thumbs down (unselected)")
                    }
                    FeedbackButton(type: .down, isSelected: true, style: .whiteBoxed) {
                        print("Thumbs down (unselected)")
                    }

                }
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.pageBackground)
}
