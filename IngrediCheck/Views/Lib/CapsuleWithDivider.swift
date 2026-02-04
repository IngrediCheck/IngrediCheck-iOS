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
            Microcopy.text(Microcopy.Key.Common.MatchStatus.analyzing)
                .foregroundStyle(Color.primary100)
        case .fail:
            Microcopy.text(Microcopy.Key.Common.MatchStatus.unmatched)
                .foregroundStyle(Color.fail200)
        case .success:
            Microcopy.text(Microcopy.Key.Common.MatchStatus.matched)
                .foregroundStyle(Color.success200)
        case .warning:
            Microcopy.text(Microcopy.Key.Common.MatchStatus.uncertain)
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
