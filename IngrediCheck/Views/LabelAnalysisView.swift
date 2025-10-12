
import SwiftUI
import SimpleToast
import PostHog

@MainActor @Observable class LabelAnalysisViewModel {
    
    let productImages: [ProductImage]
    let webService: WebService
    let dietaryPreferences: DietaryPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(_ productImages: [ProductImage], _ webService: WebService, _ dietaryPreferences: DietaryPreferences) {
        self.productImages = productImages
        self.webService = webService
        self.dietaryPreferences = dietaryPreferences
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
        let userPreferenceText = dietaryPreferences.asString
        var streamErrorHandled = false
        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        let imageCount = productImages.count

        PostHogSDK.shared.capture("Label Analysis Started", properties: [
            "request_id": requestId,
            "client_activity_id": clientActivityId,
            "image_count": imageCount,
            "has_preferences": !userPreferenceText.isEmpty && userPreferenceText.lowercased() != "none"
        ])

        do {
            try await webService.streamUnifiedAnalysis(
                input: .productImages(productImages),
                clientActivityId: clientActivityId,
                userPreferenceText: userPreferenceText,
                onProduct: { product in
                    withAnimation {
                        self.product = product
                    }
                    self.impactOccurred()

                    PostHogSDK.shared.capture("Label Analysis Product Received", properties: [
                        "request_id": requestId,
                        "client_activity_id": self.clientActivityId,
                        "image_count": imageCount,
                        "product_name": product.name ?? "Unknown",
                        "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
                    ])
                },
                onAnalysis: { recommendations in
                    withAnimation {
                        self.ingredientRecommendations = recommendations
                    }
                    self.impactOccurred()

                    PostHogSDK.shared.capture("Label Analysis Completed", properties: [
                        "request_id": requestId,
                        "client_activity_id": self.clientActivityId,
                        "image_count": imageCount,
                        "recommendations_count": recommendations.count,
                        "total_latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
                    ])
                },
                onError: { streamError in
                    streamErrorHandled = true
                    self.error = streamError

                    PostHogSDK.shared.capture("Label Analysis Failed", properties: [
                        "request_id": requestId,
                        "client_activity_id": self.clientActivityId,
                        "image_count": imageCount,
                        "status_code": streamError.statusCode ?? -1,
                        "error": streamError.message,
                        "total_latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
                    ])
                }
            )
        } catch {
            if !streamErrorHandled {
                self.error = error

                PostHogSDK.shared.capture("Label Analysis Failed", properties: [
                    "request_id": requestId,
                    "client_activity_id": clientActivityId,
                    "image_count": imageCount,
                    "status_code": -1,
                    "error": error.localizedDescription,
                    "total_latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
                ])
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
                        let newViewModel = LabelAnalysisViewModel(productImages, webService, dietaryPreferences)
                        Task { await newViewModel.analyze() }
                        DispatchQueue.main.async { self.viewModel = newViewModel }
                    }
            }
        }
    }
}
