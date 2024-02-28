import SwiftUI

struct HeaderImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.paletteSecondary, lineWidth: 0.8)
                )
        } placeholder: {
            ProgressView()
        }
        .clipped()
    }
}

struct StarButton: View {
    @State private var starred: Bool = false
    var body: some View {
        Button(action: {
            // TODO
            starred.toggle()
        }, label: {
            Image(systemName: starred ? "star.fill" : "star")
                .font(.subheadline)

        })
    }
}

struct UpvoteButton: View {
    @Binding var rating: Int

    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == 1) ? 0 : 1
            }
        }, label: {
            Image(systemName: rating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                .font(.subheadline)
        })
    }
}

struct DownvoteButton: View {
    @Binding var rating: Int

    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == -1) ? 0 : -1
            }
        }, label: {
            Image(systemName: rating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                .font(.subheadline)

        })
    }
}

@Observable class BarcodeAnalysisViewModel {

    let barcode: String
    let webService: WebService
    let userPreferences: UserPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(barcode: String, webService: WebService, userPreferences: UserPreferences) {
        self.barcode = barcode
        self.webService = webService
        self.userPreferences = userPreferences
        impactFeedback.prepare()
    }

    var product: DTO.Product?
    var notFound: Bool?
    var errorMessage: String?
    var ingredientRecommendations: [DTO.IngredientRecommendation]?
    var feedbackData = FeedbackData()
    let clientActivityId = UUID().uuidString

    func impactOccurred() {
        impactFeedback.impactOccurred()
    }

    func analyze() async {
        
        do {
            let product =
                try await webService.fetchProductDetailsFromBarcode(clientActivityId: clientActivityId, barcode: barcode)

            withAnimation {
                self.product = product
            }

            impactOccurred()

            let result =
                try await webService.fetchIngredientRecommendations(
                    clientActivityId: clientActivityId,
                    userPreferenceText: userPreferences.asString,
                    barcode: barcode)

            withAnimation {
                self.ingredientRecommendations = result
            }
            
        } catch NetworkError.notFound {
            self.notFound = true
        } catch {
            errorMessage = error.localizedDescription
        }

        impactOccurred()
    }

    func submitFeedback() {
        Task {
            try? await webService.submitFeedback(clientActivityId: clientActivityId, feedbackData: feedbackData)
        }
    }
}

struct BarcodeAnalysisView: View {
    
    @Binding var barcode: String?

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState
    
    @State private var viewModel: BarcodeAnalysisViewModel?

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        Group {
            if let viewModel {
                @Bindable var viewModelBindable = viewModel
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .padding()
                } else if let _ = viewModel.notFound {
                    VStack {
                        Spacer()
                        
                        Text("You found a Product that is not in our Database. Submit Product Images and Earn IngrediPoints\u{00A9}!")
                            .padding()
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            userPreferencesBindable.captureType = .ingredients
                            _ = appState.checkTabState.routes.popLast()
                        }, label: {
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .padding()
                        })
                        .padding()

                        Text("Product will be analyzed instantly!")
                        
                        Spacer()
                        Spacer()
                        Spacer()
                    }
                    .navigationTitle("Congratulations!")
                    .navigationBarTitleDisplayMode(.inline)
                } else if let product = viewModel.product {
                    ScrollView {
                        VStack(spacing: 15) {

                            if let name = product.name {
                                Text(name)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal)
                            }

                            if !product.images.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack(spacing: 10) {
                                        ForEach(product.images.indices, id:\.self) { index in
                                            if case let .url(url) = product.images[index] {
                                                HeaderImage(url: url)
                                                    .frame(width: UIScreen.main.bounds.width - 60)
                                            }
                                        }
                                        Button(action: {
                                            appState.activeSheet = .feedback(FeedbackConfig(
                                                feedbackData: $viewModelBindable.feedbackData,
                                                feedbackCaptureOptions: .imagesOnly,
                                                onSubmit: { viewModel.submitFeedback() }
                                            ))
                                        }, label: {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.largeTitle)
                                                .padding()
                                        })
                                    }
                                    .scrollTargetLayout()
                                }
                                .padding(.leading)
                                .scrollIndicators(.hidden)
                                .scrollTargetBehavior(.viewAligned)
                                .frame(height: (UIScreen.main.bounds.width - 60) * (4/3))
                            } else {
                                Button(action: {
                                    appState.activeSheet = .feedback(FeedbackConfig(
                                        feedbackData: $viewModelBindable.feedbackData,
                                        feedbackCaptureOptions: .imagesOnly,
                                        onSubmit: { viewModel.submitFeedback() }
                                    ))
                                }, label: {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.largeTitle)
                                        .padding()
                                })
                            }
  
                            if let brand = product.brand {
                                Text(brand)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal)
                            }
                          
                            AnalysisResultView(product: product, ingredientRecommendations: viewModel.ingredientRecommendations)
                            
                            Text(product.decoratedIngredientsList(ingredientRecommendations: viewModel.ingredientRecommendations))
                                .padding(.horizontal)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: viewModelBindable.feedbackData.rating) { oldRating, newRating in
                        switch newRating {
                        case -1:
                            appState.activeSheet = .feedback(FeedbackConfig(
                                feedbackData: $viewModelBindable.feedbackData,
                                feedbackCaptureOptions: .feedbackAndImages,
                                onSubmit: { viewModel.submitFeedback() }
                            ))
                        default:
                            viewModel.submitFeedback()
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if viewModel.ingredientRecommendations != nil {
                                if !product.images.isEmpty {
                                    Button(action: {
                                        appState.activeSheet = .feedback(FeedbackConfig(
                                            feedbackData: $viewModelBindable.feedbackData,
                                            feedbackCaptureOptions: .imagesOnly,
                                            onSubmit: { viewModel.submitFeedback() }
                                        ))
                                    }, label: {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.subheadline)
                                    })
                                }
                                StarButton()
                                UpvoteButton(rating: $viewModelBindable.feedbackData.rating)
                                DownvoteButton(rating: $viewModelBindable.feedbackData.rating)
                            }
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Looking up \(barcode!)")
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                Text("")
                    .onAppear {
                        viewModel = BarcodeAnalysisViewModel(
                            barcode: barcode!,
                            webService: webService,
                            userPreferences: userPreferences
                        )
                        Task { await viewModel?.analyze() }
                    }
            }
        }
    }
}
