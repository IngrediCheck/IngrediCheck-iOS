
import SwiftUI

@Observable class LabelAnalysisViewModel {
    
    let productImages: [ProductImage]
    let webService: WebService
    let userPreferences: UserPreferences
    
    init(_ productImages: [ProductImage], _ webService: WebService, _ userPreferences: UserPreferences) {
        self.productImages = productImages
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
                productImages: productImages
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
    
    let productImages: [ProductImage]

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
                        VStack(spacing: 0) {

                            if let brand = product.brand {
                                Text(brand)
                            }

                            if let name = product.name {
                                Text(name)
                            }

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
                            .scrollIndicators(.hidden)
                            .scrollTargetBehavior(.viewAligned)
                            .frame(height: (UIScreen.main.bounds.width - 20) * (4/3))
                            
                            AnalysisResultView(product: product, ingredientRecommendations: viewModel.ingredientRecommendations)
                                .padding(.vertical)
                            
                            Text(product.decoratedIngredientsList(ingredientRecommendations: viewModel.ingredientRecommendations))
                                .padding(.vertical)
                            
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
                    .scrollIndicators(.hidden)
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
                        viewModel = LabelAnalysisViewModel(productImages, webService, userPreferences)
                        Task { await viewModel?.analyze() }
                    }
            }
        }
    }
}
