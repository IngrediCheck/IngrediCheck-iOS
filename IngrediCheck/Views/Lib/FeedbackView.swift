import SwiftUI


struct CloseButton : View {

    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Button(action: {
            dismiss()
        }, label: {
            Image(systemName: "x.circle")
        })
    }
}

struct FeedbackView: View {

    let onSubmit: (String) -> Void

    @State private var feedbackText: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("What should I look into?")
                    .padding(.horizontal)
                
                TextEditor(text: $feedbackText)
                    .frame(height: 120)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                Button(action: {
                    onSubmit(feedbackText)
                    dismiss()
                }) {
                    Text("Submit")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(feedbackText.isEmpty ? .gray : .paletteAccent)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(feedbackText.isEmpty)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Help me Improve 🥹")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: CloseButton())
        }
    }
}

#Preview {
    FeedbackView() { feedbackText in
        print(feedbackText)
    }
}
