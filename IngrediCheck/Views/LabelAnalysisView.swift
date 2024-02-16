
import SwiftUI

@Observable class LabelAnalysisViewModel {
    
    let productImages: [ProductImage]
    let webService: WebService
    let userPreferences: UserPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(_ productImages: [ProductImage], _ webService: WebService, _ userPreferences: UserPreferences) {
        self.productImages = productImages
        self.webService = webService
        self.userPreferences = userPreferences
        impactFeedback.prepare()
    }
    
    var product: DTO.Product? = nil
    var error: Error? = nil
    var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil
    let clientActivityId = UUID().uuidString

    func impactOccurred() {
        impactFeedback.impactOccurred()
    }

    func analyze() async {
        do {
            product = try await webService.extractProductDetailsFromLabelImages(
                clientActivityId: clientActivityId,
                productImages: productImages
            )
            impactOccurred()

            let result =
                try await webService.fetchIngredientRecommendations(
                    clientActivityId: clientActivityId,
                    userPreferenceText: userPreferences.asString)

            withAnimation {
                ingredientRecommendations = result
            }
        } catch {
            self.error = error
        }

        impactOccurred()
    }

    func submitRating(rating: Int) {
        Task {
            try? await webService.submitFeedbackRating(clientActivityId: clientActivityId, rating: rating)
        }
    }

    func submitFeedbackText(feedbackText: String) {
        guard !feedbackText.isEmpty else { return }
        Task {
            try? await webService.submitFeedbackText(clientActivityId: clientActivityId, feedbackText: feedbackText)
        }
    }
}

struct LabelAnalysisView: View {
    
    let productImages: [ProductImage]

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState

    @State private var rating: Int = 0
    @State private var viewModel: LabelAnalysisViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if let error = viewModel.error {
                    Text("Error: \(error.localizedDescription)")
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

                            // Note: we are not using product.images here.
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(productImages.indices, id: \.self) { index in
                                        Image(uiImage: productImages[index].image)
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.paletteSecondary, lineWidth: 0.8)
                                            )
                                            .frame(width: UIScreen.main.bounds.width - 60)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .padding(.leading)
                            .scrollIndicators(.hidden)
                            .scrollTargetBehavior(.viewAligned)
                            .frame(height: (UIScreen.main.bounds.width - 60) * (4/3))

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
                        viewModel.submitRating(rating: newRating)
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
                                AddImagesButton()
                            }
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Analyzing Image...")
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                Text("")
                    .onAppear {
                        viewModel = LabelAnalysisViewModel(productImages, webService, userPreferences)
                        Task { await viewModel?.analyze() }
                    }
            }
        }
    }
}
