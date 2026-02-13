import SwiftUI

struct StarButton: View {
    let clientActivityId: String
    @State private var favorited: Bool
    @Environment(WebService.self) var webService

    init(clientActivityId: String, favorited: Bool) {
        self.clientActivityId = clientActivityId
        self.favorited = favorited
    }

    var body: some View {
        Button(action: {
            favorited.toggle()
        }, label: {
            Image(systemName: favorited ? "heart.fill" : "heart")
                .font(.subheadline)
                .foregroundStyle(favorited ? .red : .paletteAccent)
        })
        .onChange(of: favorited) { oldValue, newValue in
            Task {
                if newValue {
                    try await webService.addToFavorites(clientActivityId: clientActivityId)
                } else {
                    try await webService.removeFromFavorites(clientActivityId: clientActivityId)
                }
            }
        }
    }
}
