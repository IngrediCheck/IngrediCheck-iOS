import SwiftUI
import SwiftUIFlowLayout
import SimpleToast
import PostHog

struct HeaderImage: View {
    let imageLocation: DTO.ImageLocationInfo

    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ProgressView()
                .task {
                    if let image = try? await webService.fetchImage(imageLocation: imageLocation, imageSize: .medium) {
                        DispatchQueue.main.async {
                            self.image = image
                        }
                    }
                }
        }
    }
}

struct StarButton: View {
    let clientActivityId: String
    @State private var favorited: Bool
    @Environment(WebService.self) var webService
    
    init(clientActivityId: String, favorited: Bool) {
        self.clientActivityId = clientActivityId
        self.favorited = favorited
    }
    
    var body: some View {
        Button(action: {
            favorited.toggle()
        }, label: {
            Image(systemName: favorited ? "heart.fill" : "heart")
                .font(.subheadline)
                .foregroundStyle(favorited ? .red : .paletteAccent)
        })
        .onChange(of: favorited) { oldValue, newValue in
            Task {
                if newValue {
                    try await webService.addToFavorites(clientActivityId: clientActivityId)
                } else {
                    try await webService.removeFromFavorites(clientActivityId: clientActivityId)
                }
            }
        }
    }
}

@Observable class BarcodeAnalysisViewModel {

    let barcode: String
    let webService: WebService
    let dietaryPreferences: DietaryPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(_ barcode: String, _ webService: WebService, _ dietaryPreferences: DietaryPreferences) {
        self.barcode = barcode
        self.webService = webService
        self.dietaryPreferences = dietaryPreferences
        impactFeedback.prepare()
    }

    @MainActor var product: DTO.Product?
    @MainActor var notFound: Bool?
    @MainActor var errorMessage: String?
    @MainActor var ingredientRecommendations: [DTO.IngredientRecommendation]?
    @MainActor var feedbackData = FeedbackData()
    let clientActivityId = UUID().uuidString

    func impactOccurred() {
        impactFeedback.impactOccurred()
    }

    func analyze() async {
        
        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        let userPreferenceText = await dietaryPreferences.asString
        
        PostHogSDK.shared.capture("Analysis Started", properties: [
            "request_id": requestId,
            "client_activity_id": clientActivityId,
            "barcode": barcode,
            "has_preferences": !userPreferenceText.isEmpty && userPreferenceText.lowercased() != "none"
        ])
        
        do {
            let product =
                try await webService.fetchProductDetailsFromBarcode(clientActivityId: clientActivityId, barcode: barcode)

            await MainActor.run {
                withAnimation {
                    self.product = product
                }
            }

            impactOccurred()

            let result =
                try await webService.fetchIngredientRecommendations(
                    clientActivityId: clientActivityId,
                    userPreferenceText: userPreferenceText,
                    barcode: barcode)

            await MainActor.run {
                withAnimation {
                    self.ingredientRecommendations = result
                }
            }
            
            let endTime = Date().timeIntervalSince1970
            let totalLatency = (endTime - startTime) * 1000
            
            PostHogSDK.shared.capture("Analysis Completed", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "product_name": product.name ?? "Unknown",
                "recommendations_count": result.count,
                "total_latency_ms": totalLatency
            ])
            
        } catch NetworkError.notFound {
            await MainActor.run {
                self.notFound = true
            }
            
            let endTime = Date().timeIntervalSince1970
            let totalLatency = (endTime - startTime) * 1000
            
            PostHogSDK.shared.capture("Analysis Failed - Product Not Found", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "total_latency_ms": totalLatency
            ])
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            
            let endTime = Date().timeIntervalSince1970
            let totalLatency = (endTime - startTime) * 1000
            
            PostHogSDK.shared.capture("Analysis Failed - Error", properties: [
                "request_id": requestId,
                "client_activity_id": clientActivityId,
                "barcode": barcode,
                "error": error.localizedDescription,
                "total_latency_ms": totalLatency
            ])
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
    
    let barcode: String

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState
    @Environment(CheckTabState.self) var checkTabState
    
    @State private var viewModel: BarcodeAnalysisViewModel?
    @State private var showToast: Bool = false

    @MainActor
    @ViewBuilder
    var notFoundView: some View {
        @Bindable var userPreferencesBindable = userPreferences
        VStack {
            Spacer()
            
            Text("You found a Product that is not in our Database. Submit Product Images and Earn IngrediPoints\u{00A9}!")
                .padding()
                .multilineTextAlignment(.center)
            
            Button(action: {
                userPreferencesBindable.captureType = .ingredients
                _ = checkTabState.routes.popLast()
            }, label: {
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                        .padding()
                    Text("Upload photos")
                        .foregroundStyle(.primary100)
                        .font(.headline)
                }
                .frame(width: UIScreen.main.bounds.width / 2)
                .frame(height: UIScreen.main.bounds.width / 2)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.primary50)
                }
            })
            .padding()

            Text("Product will be analyzed instantly!")
            
            Spacer()
            Spacer()
            Spacer()
        }
        .navigationTitle("Congratulations!")
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        Group {
            if let viewModel {
                @Bindable var viewModelBindable = viewModel
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .padding()
                } else if let _ = viewModel.notFound {
                    notFoundView
                } else if let product = viewModel.product {
                    if product.images.isEmpty && product.ingredients.isEmpty {
                        notFoundView
                    } else {
                        ScrollView {
                            VStack(spacing: 15) {
                                
                                if let name = product.name {
                                    Text(name)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .padding(.horizontal)
                                }
                                                                
                                if let brand = product.brand {
                                    Text(brand)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .padding(.horizontal)
                                }

                                ProductImagesView(images: product.images) {
                                    checkTabState.feedbackConfig = FeedbackConfig(
                                        feedbackData: $viewModelBindable.feedbackData,
                                        feedbackCaptureOptions: .imagesOnly,
                                        onSubmit: {
                                            showToast.toggle()
                                            viewModel.submitFeedback()
                                        }
                                    )
                                }
                                
                                if product.ingredients.isEmpty {
                                    Text("Help! Our Product Database is missing an Ingredient List for this Product. Submit Product Images and Earn IngrediPoiints\u{00A9}!")
                                        .font(.subheadline)
                                        .padding()
                                        .multilineTextAlignment(.center)
                                    Button(action: {
                                        userPreferencesBindable.captureType = .ingredients
                                        _ = checkTabState.routes.popLast()
                                    }, label: {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.largeTitle)
                                    })
                                    Text("Product will be analyzed instantly!")
                                        .font(.subheadline)
                                } else {
                                    AnalysisResultView(product: product, ingredientRecommendations: viewModel.ingredientRecommendations)
                                    
                                    HStack {
                                        Text("Ingredients") .font(.headline)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    
                                    IngredientsText(ingredients: product.ingredients, ingredientRecommendations: viewModel.ingredientRecommendations)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .simpleToast(isPresented: $showToast, options: SimpleToastOptions(hideAfter: 3)) {
                            FeedbackSuccessToastView()
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                if viewModel.ingredientRecommendations != nil {
                                    if !product.images.isEmpty && !product.ingredients.isEmpty {
                                        Button(action: {
                                            checkTabState.feedbackConfig = FeedbackConfig(
                                                feedbackData: $viewModelBindable.feedbackData,
                                                feedbackCaptureOptions: .imagesOnly,
                                                onSubmit: {
                                                    showToast.toggle()
                                                    viewModel.submitFeedback()
                                                }
                                            )
                                        }, label: {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.subheadline)
                                        })
                                    }
                                    StarButton(clientActivityId: viewModel.clientActivityId, favorited: false)
                                    Button(action: {
                                        checkTabState.feedbackConfig = FeedbackConfig(
                                            feedbackData: $viewModelBindable.feedbackData,
                                            feedbackCaptureOptions: .feedbackAndImages,
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
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Looking up \(barcode)")
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                ProgressView()
                    .task {
                        let newViewModel = BarcodeAnalysisViewModel(barcode, webService, dietaryPreferences)
                        Task { await newViewModel.analyze() }
                        DispatchQueue.main.async { self.viewModel = newViewModel }
                    }
            }
        }
    }
}

struct IngredientsText: View {
    let ingredients: [DTO.Ingredient]
    let ingredientRecommendations: [DTO.IngredientRecommendation]?
    var body: some View {
        let decoratedFragments =
            DTO.decoratedIngredientsList(
                ingredients: ingredients,
                ingredientRecommendations: ingredientRecommendations
            )
        FlowLayout(mode: .scrollable, items: decoratedFragments, itemSpacing: 0) { fragment in
            TappableTextFragment(fragment: fragment)
        }
    }
}

struct TappableTextFragment: View {
    let fragment: DTO.DecoratedIngredientListFragment
    @State private var showPopover = false
    
    var body: some View {
        switch fragment.safetyRecommendation {
        case .maybeUnsafe:
            Text(fragment.fragment)
                .font(.body)
                .foregroundStyle(.warning200)
                .underline(true, pattern: .dot)
                .background(Color.warning25)
                .onTapGesture {
                    showPopover = true
                }
                .popover(isPresented: $showPopover, content: {
                    VStack {
                        Text(fragment.preference!)
                            .padding()
                    }
                    .presentationCompactAdaptation(.popover)
                })
        case .definitelyUnsafe:
            Text(fragment.fragment)
                .font(.body)
                .foregroundStyle(.fail200)
                .underline(true, pattern: .dot)
                .background(Color.fail25)
                .onTapGesture {
                    showPopover = true
                }
                .popover(isPresented: $showPopover, content: {
                    VStack {
                        Text(fragment.preference!)
                            .padding()
                    }
                    .presentationCompactAdaptation(.popover)
                })
        case .safe, .none:
            Text(fragment.fragment)
                .font(.body)
//        case .none:
//            Text(fragment.fragment)
//                .font(.body)
//                .underline(true, pattern: .dot)
//                .background(
//                    .blue.opacity(0.15)
//                )
        }
    }
}
