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

struct UpvoteButton: View {
    @Binding var rating: Int

    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == 1) ? 0 : 1
            }
        }, label: {
            Image(systemName: rating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
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
    
    func submitUpVote() {
        Task {
            try? await webService.submitUpVote(clientActivityId: clientActivityId)
        }
    }
    
    func submitFeedbackText(feedbackText: String) {
        guard !feedbackText.isEmpty else { return }
        Task {
            try? await webService.submitFeedbackText(clientActivityId: clientActivityId, feedbackText: feedbackText)
        }
    }
}

struct BarcodeAnalysisView: View {
    
    @Binding var barcode: String?

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState
    
    @State private var rating: Int = 0
    @State private var viewModel: BarcodeAnalysisViewModel?

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        Group {
            if let viewModel {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .padding()
                } else if let _ = viewModel.notFound {
                    VStack {
                        Text("Congratulations!")
                        Text("You found a product that is not in our Database.")
                        Text("Earn Ingredipoints by submitting photos!")
                        Button(action: {
                            userPreferencesBindable.captureType = .ingredients
                            _ = appState.checkTabState.routes.popLast()
                        }, label: {
                            Text("Click here to add Photos")
                        })
                        .padding(.top)
                    }
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
                                        addImagesButton
                                    }
                                    .scrollTargetLayout()
                                }
                                .padding(.leading)
                                .scrollIndicators(.hidden)
                                .scrollTargetBehavior(.viewAligned)
                                .frame(height: (UIScreen.main.bounds.width - 60) * (4/3))
                            } else {
                                addImagesButton
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
                    .onChange(of: rating) { oldRating, newRating in
                        if newRating == 1 {
                            viewModel.submitUpVote()
                        }
                        if newRating == -1 {
                            appState.activeSheet = .captureFeedback(onSubmit: { feedbackText in
                                viewModel.submitFeedbackText(feedbackText: feedbackText)
                            })
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if viewModel.ingredientRecommendations != nil {
                                UpvoteButton(rating: $rating)
                                DownvoteButton(rating: $rating)
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
    
    var addImagesButton: some View {
        Button(action: {
            // TODO
        }, label: {
            Image(systemName: "photo.badge.plus")
                .font(.largeTitle)
                .padding()
        })
    }
}
