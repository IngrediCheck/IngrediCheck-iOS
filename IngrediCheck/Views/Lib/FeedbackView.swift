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
            case .feedbackOnly:
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 24, height: 14)
                                    .foregroundStyle(.grayScale150)
                            }
                            Spacer()
                            Text("Share Your Feedback")
                                .font(NunitoFont.bold.size(22))
                                .foregroundStyle(.grayScale150)
                            Spacer()
                            // spacer to balance header
                            Color.clear.frame(width: 24, height: 24)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 15)
                        .padding(.bottom, 12)

                        // Description
                        Text("Thanks for your feedback! Your ideas, issues, and praise help us improve. Please share your thoughts below.")
                            .frame(width :333)
                            .font(ManropeFont.regular.size(12))
                            .foregroundStyle(.grayScale120)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // Rating section
                        VStack( spacing: 16) {
                            Text("How is your experience with our app?")
                                .font(NunitoFont.bold.size(16))
                                .foregroundStyle(.grayScale150)
                            

                            HStack(spacing: 8) {
                                ratingOption(emoji: "😠", title: "Terrible", value: 1)
                                ratingOption(emoji: "☹️", title: "Bad", value: 2)
                                ratingOption(emoji: "🙂", title: "Average", value: 3)
                                ratingOption(emoji: "😊", title: "Good", value: 4)
                                ratingOption(emoji: "😍", title: "Excellent", value: 5)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        // Comment section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tell us what you think of this app")
                                .font(NunitoFont.bold.size(16))
                                .foregroundStyle(.grayScale150)
                            Text("(Optional)")
                                .font(NunitoFont.regular.size(12))
                                .foregroundStyle(.grayScale110)
                                .padding(.bottom ,12)

                          ZStack(alignment: .topLeading) {
                               RoundedRectangle(cornerRadius: 10)
                                   .fill(.white)
                                   .frame(height: 47)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "#E3E3E3"), lineWidth: 1)
                                    )
                                  
                               TextEditor(text: $feedbackData.note)
                                   .focused($isFocused)
                                   .scrollContentBackground(.hidden) 
                                   .padding(12)
                                   .frame(height: 47)
                                   .foregroundStyle(.grayScale150)
                               if !isFocused && feedbackData.note.isEmpty {
                                    Text("")
                               }
                          }
                        }
                        .padding(.horizontal, 20)

                        // Submit button
                        Button {
                            onSubmit()
                            dismiss()
                        } label: {
                            GreenCapsule(title: "Submit")
                                .frame(width: 180)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 28)
                    }.background(Color.white)
                    .padding(.vertical, 16)
                }
                .background(.white)
                .scrollIndicators(.hidden)
                .toolbar(.hidden, for: .navigationBar)
                .gesture(TapGesture().onEnded { isFocused = false })
                .presentationDetents([.height(479)])
                .presentationBackground(.regularMaterial)
            case .feedbackAndImages:
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
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary, lineWidth: 1))
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
                .navigationBarItems(leading: cancelButton, trailing: nextOrSubmitButton)
                .gesture(TapGesture().onEnded { isFocused = false })
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

    @ViewBuilder
    private func ratingOption(emoji: String, title: String, value: Int) -> some View {
        Button {
            feedbackData.rating = value
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(feedbackData.rating == value ? Color(hex: "#EEF5E3") : Color(hex: "#F9F9F8"))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(feedbackData.rating == value ? Color(hex: "#75990E") : .grayScale50, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    Text(emoji)
                        .font(.system(size: 28))
                }
                Text(title)
                    .font(NunitoFont.medium.size(12))
                    .foregroundStyle(feedbackData.rating == value ? .grayScale150 : .grayScale110)
            }
        }
        .buttonStyle(.plain)
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

struct FeedbackSuccessToastView: View {
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Color.success100)
            Text("Feedback recorded. Thank you!")
        }
        .frame(minWidth: UIScreen.main.bounds.width * 3 / 4)
        .padding()
        .background(Color.success50)
        .foregroundColor(Color.primary)
        .cornerRadius(10)
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
