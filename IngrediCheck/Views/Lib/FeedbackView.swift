import SwiftUI

enum FeedbackReason: String, CaseIterable, Identifiable {
    case productImageIssue = "Product Images."
    case ingredientIssue = "Product Information."
    case analysisIssue = "Incorrect Analysis."

    var id: String { self.rawValue }
}

struct FeedbackData {
    var rating: Int = 0
    var reasons: Set<FeedbackReason> = []
    var note: String = ""
    var images: [ProductImage] = []
}

enum FeedbackCaptureOptions {
    case feedbackOnly
    case feedbackAndImages
    case imagesOnly
}

struct FeedbackConfig {
    let feedbackData: Binding<FeedbackData>
    let feedbackCaptureOptions: FeedbackCaptureOptions
    let onSubmit: () -> Void
}

struct FeedbackView: View {

    @Binding var feedbackData: FeedbackData
    let feedbackCaptureOptions: FeedbackCaptureOptions
    let onSubmit: () -> Void

    @Environment(\.dismiss) var dismiss
    @FocusState var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    Text("What should I look into?")
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(FeedbackReason.allCases, id: \.self) { reason in
                            HStack {
                                Image(systemName: feedbackData.reasons.contains(reason) ? "checkmark.square" : "square")
                                Text(reason.rawValue)
                                Spacer()
                            }
                            .onTapGesture {
                                if feedbackData.reasons.contains(reason) {
                                    feedbackData.reasons.remove(reason)
                                } else {
                                    feedbackData.reasons.insert(reason)
                                }
                            }
                        }
                    }
                    
                    TextEditor(text: $feedbackData.note)
                        .focused($isFocused)
                        .frame(height: 120)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary, lineWidth: 1)
                        )
                        .overlay(
                            VStack(alignment: .leading) {
                                Text("Optionally, leave me a note here.")
                                    .foregroundColor(.gray)
                                    .opacity(isFocused ? 0 : 1)
                                    .padding()
                                Spacer()
                            }
                        )

                    Spacer()
                }
            }
            .scrollIndicators(.hidden)
            .padding()
            .navigationTitle("Help me Improve 🥹")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: cancelButton,
                trailing: nextOrSubmitButton
            )
            .gesture(TapGesture().onEnded {
                isFocused = false
            })
        }
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }
    
    private var nextOrSubmitButtonTitle: String {
        if captureImages {
            "Next"
        } else {
            "Submit"
        }
    }
    
    private var nextOrSubmitButton: some View {
        Button(nextOrSubmitButtonTitle) {
            if captureImages {
                // TODO
            } else {
                onSubmit()
                dismiss()
            }
        }
    }
    
    private var captureImages: Bool {
        switch feedbackCaptureOptions {
        case .feedbackOnly:
            false
        case .feedbackAndImages:
            true
        case .imagesOnly:
            true
        }
    }
}

struct FeedbackViewPreview: View {
    @State private var feedbackData = FeedbackData()
    
    var body: some View {
        FeedbackView(feedbackData: $feedbackData, feedbackCaptureOptions: .feedbackOnly) {
            print(feedbackData)
        }
    }
}

#Preview {
    FeedbackViewPreview()
}
