import SwiftUI

enum CapsuleState {
    case success
    case fail
    case warning
    case analyzing
}

extension CapsuleState {
    
    var textView: some View {
        switch self {
        case .analyzing:
            Text("Analyzing")
                .foregroundStyle(Color.primary100)
        case .fail:
            Text("Unmatched")
                .foregroundStyle(Color.fail200)
        case .success:
            Text("Matched")
                .foregroundStyle(Color.success200)
        case .warning:
            Text("Uncertain")
                .foregroundStyle(Color.warning200)
        }
    }
    
    var background: Color {
        switch self {
        case .analyzing:
            Color.primary50
        case .fail:
            Color.fail25
        case .success:
            Color.success50
        case .warning:
            Color.warning50
        }
    }
    
    @ViewBuilder
    var imageView: some View {
        switch self {
        case .analyzing:
            ProgressView()
                .foregroundStyle(Color.primary100)
        case .fail:
            Image(systemName: "x.circle.fill")
                .foregroundStyle(Color.fail100)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.success100)
        case .warning:
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(Color.warning100)
        }
    }
}

struct CapsuleWithDivider: View {

    let state: CapsuleState

    var body: some View {
        HStack(spacing: 15) {
            Spacer()
            state.imageView
            state.textView
            Spacer()
        }
        .font(.title3)
        .fontWeight(.semibold)
        .padding(.vertical, 15)
        .background(state.background)
    }
}

#Preview {
    CapsuleWithDivider(state: .analyzing)
}
