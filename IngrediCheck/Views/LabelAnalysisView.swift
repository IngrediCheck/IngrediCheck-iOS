
import SwiftUI

@Observable class LabelAnalysisViewModel {
    
    let ingredientLabel: IngredientLabel
    let webService: WebService
    let userPreferences: UserPreferences
    
    init(ingredientLabel: IngredientLabel, webService: WebService, userPreferences: UserPreferences) {
        self.ingredientLabel = ingredientLabel
        self.webService = webService
        self.userPreferences = userPreferences
    }
    
    var product: DTO.Product? = nil
    var error: Error? = nil
    var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil
    let clientActivityId = UUID().uuidString

    func analyze() async {
        do {
            self.product = try await webService.extractProductDetailsFromLabelImages(
                clientActivityId: clientActivityId,
                labelImages: [ingredientLabel]
            )
            let result =
                try await webService.fetchIngredientRecommendations(
                    clientActivityId: clientActivityId,
                    userPreferenceText: userPreferences.asString
                )
            withAnimation {
                ingredientRecommendations = result
            }
        } catch {
            self.error = error
        }
    }
    
    func submitRating(rating: Int) async {
        try? await webService.rateAnalysis(clientActivityId: clientActivityId, rating: rating)
    }
}

struct LabelAnalysisView: View {
    
    let ingredientLabel: IngredientLabel
    
    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences

    @State private var rating: Int = 0
    @State private var viewModel: LabelAnalysisViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if let error = viewModel.error {
                    Text("Error: \(error.localizedDescription)")
                } else if let product = viewModel.product {
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(uiImage: ingredientLabel.image)
                                .resizable()
                                .scaledToFit()
                            if let brand = product.brand {
                                Text(brand)
                            }
                            if let name = product.name {
                                Text(name)
                            }
                            
                            AnalysisResultView(product: product, ingredientRecommendations: viewModel.ingredientRecommendations)
                                .padding(.bottom)
                            
                            Text(product.decoratedIngredientsList(ingredientRecommendations: viewModel.ingredientRecommendations))
                                .padding(.top)
                            
                            if viewModel.ingredientRecommendations != nil {
                                HStack(spacing: 25) {
                                    Spacer()
                                    UpvoteButton(rating: $rating)
                                    DownvoteButton(rating: $rating)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: rating) { oldRating, newRating in
                        Task { await viewModel.submitRating(rating: newRating) }
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
                        viewModel = LabelAnalysisViewModel(
                            ingredientLabel: ingredientLabel,
                            webService: webService,
                            userPreferences: userPreferences
                        )
                        Task { await viewModel?.analyze() }
                    }
            }
        }
    }
}
