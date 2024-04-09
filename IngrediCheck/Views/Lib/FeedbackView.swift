import SwiftUI

enum FeedbackReason: String, CaseIterable, Identifiable {
    case productImageIssue = "Product Images."
    case ingredientIssue = "Product Information."
    case analysisIssue = "Incorrect Analysis."

    var id: String { self.rawValue }
}

struct FeedbackData {
    var reasons: Set<FeedbackReason> = []
    var note: String = ""
    var images: [ProductImage] = []
    
    // This is not used anymore, since we are not showing a downvote button anymore.
    var rating: Int = 0
}

enum FeedbackCaptureOptions {
    case feedbackOnly
    case feedbackAndImages
    case imagesOnly
}

struct FeedbackConfig : Identifiable {
    let feedbackData: Binding<FeedbackData>
    let feedbackCaptureOptions: FeedbackCaptureOptions
    let onSubmit: () -> Void
    let id = UUID()
}

struct FeedbackView: View {

    @Binding var feedbackData: FeedbackData
    let feedbackCaptureOptions: FeedbackCaptureOptions
    let onSubmit: () -> Void

    @Environment(\.dismiss) var dismiss
    @FocusState var isFocused: Bool
    
    @State private var routes = NavigationPath()

    var body: some View {
        NavigationStack(path: $routes) {
            switch feedbackCaptureOptions {
            case .feedbackOnly, .feedbackAndImages:
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
                                Group {
                                    if !isFocused && feedbackData.note.isEmpty {
                                        Text("Optionally, leave me a note here.")
                                            .foregroundColor(.gray)
                                    }
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
                .navigationDestination(for: String.self) { item in
                    if item == "captureImages" {
                        ImageCaptureView(
                            capturedImages: $feedbackData.images,
                            onSubmit: { onSubmit(); dismiss() },
                            showClearButton: false,
                            showTitle: true,
                            showCancelButton: false
                        )
                        .padding(.horizontal)
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(.regularMaterial)
            case .imagesOnly:
                ImageCaptureView(
                    capturedImages: $feedbackData.images,
                    onSubmit: { onSubmit(); dismiss() },
                    showClearButton: false,
                    showTitle: true,
                    showCancelButton: true
                )
                    .presentationDetents([.large])
                    .presentationBackground(.regularMaterial)
                    .padding(.horizontal)
            }
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
                routes.append("captureImages")
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
