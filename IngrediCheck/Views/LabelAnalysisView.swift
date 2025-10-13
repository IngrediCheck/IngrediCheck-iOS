
import SwiftUI
import SimpleToast

@Observable class LabelAnalysisViewModel {
    
    let productImages: [ProductImage]
    let webService: WebService
    let dietaryPreferences: DietaryPreferences
    let userPreferences: UserPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(_ productImages: [ProductImage], _ webService: WebService, _ dietaryPreferences: DietaryPreferences, _ userPreferences: UserPreferences) {
        self.productImages = productImages
        self.webService = webService
        self.dietaryPreferences = dietaryPreferences
        self.userPreferences = userPreferences
        impactFeedback.prepare()
    }
    
    @MainActor var product: DTO.Product? = nil
    @MainActor var error: Error? = nil
    @MainActor var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil
    @MainActor var feedbackData = FeedbackData()
    let clientActivityId = UUID().uuidString

    func impactOccurred() {
        impactFeedback.impactOccurred()
    }

    func analyze() async {
        do {
            let product =
                try await webService.extractProductDetailsFromLabelImages(
                    clientActivityId: clientActivityId,
                    productImages: productImages
                )

            await MainActor.run {
                withAnimation {
                    self.product = product
                }
            }
            
            impactOccurred()

            let result =
                try await webService.fetchIngredientRecommendations(
                    clientActivityId: clientActivityId,
                    userPreferenceText: dietaryPreferences.asString)

            await MainActor.run {
                withAnimation {
                    ingredientRecommendations = result
                }
            }
            
            // Track successful scan for rating prompt
            userPreferences.incrementScanCount()
        } catch {
            await MainActor.run {
                self.error = error
            }
        }

        impactOccurred()
    }

    func submitFeedback() {
        Task {
            try? await webService.submitFeedback(clientActivityId: clientActivityId, feedbackData: feedbackData)
        }
    }
}

struct LabelAnalysisView: View {
    
    let productImages: [ProductImage]

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState
    @Environment(CheckTabState.self) var checkTabState

    @State private var viewModel: LabelAnalysisViewModel?
    @State private var showToast: Bool = false

    var body: some View {
        Group {
            if let viewModel {
                @Bindable var viewModelBindable = viewModel
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

                            ProductImagesView(images: product.images) {
                                Task { @MainActor in
                                    checkTabState.capturedImages = productImages
                                    _ = checkTabState.routes.popLast()
                                }
                            }

                            if let brand = product.brand {
                                Text(brand)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal)
                            }
                            
                            AnalysisResultView(product: product, ingredientRecommendations: viewModel.ingredientRecommendations)
                            
                            HStack {
                                Text("Ingredients").font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            IngredientsText(ingredients: product.ingredients, ingredientRecommendations: viewModel.ingredientRecommendations)
                                .padding(.horizontal)
                        }
                    }
                    .simpleToast(isPresented: $showToast, options: SimpleToastOptions(hideAfter: 3)) {
                        FeedbackSuccessToastView()
                    }
                    .scrollIndicators(.hidden)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if viewModel.ingredientRecommendations != nil {
                                Button(action: {
                                    checkTabState.capturedImages = productImages
                                    _ = checkTabState.routes.popLast()
                                }, label: {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.subheadline)
                                })
                                StarButton(clientActivityId: viewModel.clientActivityId, favorited: false)
                                Button(action: {
                                    checkTabState.feedbackConfig = FeedbackConfig(
                                        feedbackData: $viewModelBindable.feedbackData,
                                        feedbackCaptureOptions: .feedbackOnly,
                                        onSubmit: {
                                            showToast.toggle()
                                            viewModel.submitFeedback()
                                        }
                                    )
                                }, label: {
                                    Image(systemName: "flag")
                                        .font(.subheadline)
                                })
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
                ProgressView()
                    .task {
                        let newViewModel = LabelAnalysisViewModel(productImages, webService, dietaryPreferences, userPreferences)
                        Task { await newViewModel.analyze() }
                        DispatchQueue.main.async { self.viewModel = newViewModel }
                    }
            }
        }
    }
}
