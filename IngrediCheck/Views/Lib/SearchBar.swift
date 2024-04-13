import SwiftUI

struct SearchBar: View {

    @Binding var searchText: String
    @Binding var isSearching: Bool

    @FocusState var isFocused: Bool

    var body: some View {
        HStack {
            TextField("Type to search", text: $searchText)
                .focused($isFocused)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        Button(action: {
                            self.searchText = ""
                        }) {
                            Image(systemName: "multiply.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)
                        }
                    }
                )

            Button(action: {
                self.searchText = ""
                isSearching = false
            }) {
                Text("Cancel")
            }
            .transition(.move(edge: .trailing))
        }
        .onAppear {
            isFocused = true
        }
    }
}
