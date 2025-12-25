import SwiftUI
import SwiftUIFlowLayout
import SimpleToast
import PostHog

struct HeaderImage: View {
    let imageLocation: DTO.ImageLocationInfo

    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
            }
        }
        .task(id: imageLocation) {
            // Reset before loading a new image when imageLocation changes
            image = nil
            if let loaded = try? await webService.fetchImage(imageLocation: imageLocation, imageSize: .medium) {
                await MainActor.run {
                    self.image = loaded
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

@MainActor @Observable class BarcodeAnalysisViewModel {

    let barcode: String
    let webService: WebService
    let dietaryPreferences: DietaryPreferences
    let userPreferences: UserPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(_ barcode: String, _ webService: WebService, _ dietaryPreferences: DietaryPreferences, _ userPreferences: UserPreferences) {
        self.barcode = barcode
        self.webService = webService
        self.dietaryPreferences = dietaryPreferences
        self.userPreferences = userPreferences
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
        let userPreferenceText = dietaryPreferences.asString
        var streamErrorHandled = false

        print("[BarcodeAnalysisView] analyze() started requestId=\(requestId) barcode=\(barcode) userPreferenceText='\(userPreferenceText)'")

        PostHogSDK.shared.capture("Barcode Analysis Started", properties: [
            "request_id": requestId,
            "client_activity_id": clientActivityId,
            "barcode": barcode,
            "has_preferences": !userPreferenceText.isEmpty && userPreferenceText.lowercased() != "none"
        ])

        do {
            try await webService.streamBarcodeScan(
                barcode: barcode,
                onProductInfo: { [self] productInfo, scanId in
                    print("[BarcodeAnalysisView] onProductInfo scanId=\(scanId) name='\(productInfo.name ?? "nil")'")
                    // Convert ScanProductInfo to Product for UI compatibility
                    let convertedProduct = self.webService.convertScanProductInfoToProduct(productInfo, barcode: barcode)
                    withAnimation {
                        self.product = convertedProduct
                    }
                    self.impactOccurred()

                    PostHogSDK.shared.capture("Barcode Analysis Product Received", properties: [
                        "request_id": requestId,
                        "client_activity_id": self.clientActivityId,
                        "barcode": self.barcode,
                        "scan_id": scanId,
                        "product_name": productInfo.name ?? "Unknown",
                        "latency_ms": (Date().timeIntervalSince1970 - startTime) * 1000
                    ])
                },
                onAnalysis: { [self] analysisResult in
                    // Convert ScanAnalysisResult to IngredientRecommendations for UI compatibility
                    let recommendations = self.webService.convertScanAnalysisResultToRecommendations(analysisResult)
                    print("[BarcodeAnalysisView] onAnalysis count=\(recommendations.count)")
                    withAnimation {
                        self.ingredientRecommendations = recommendations
                    }
                    self.impactOccurred()

                    let totalLatency = (Date().timeIntervalSince1970 - startTime) * 1000

                    PostHogSDK.shared.capture("Barcode Analysis Completed", properties: [
                        "request_id": requestId,
                        "client_activity_id": self.clientActivityId,
                        "barcode": self.barcode,
                        "product_name": self.product?.name ?? "Unknown",
                        "recommendations_count": recommendations.count,
                        "total_latency_ms": totalLatency
                    ])
                    
                    // Track successful scan for rating prompt - only when analysis is fully complete
                    self.userPreferences.incrementScanCount()
                },
                onError: { streamError, _ in
                    print("[BarcodeAnalysisView] onError message='\(streamError.message)' status=\(String(describing: streamError.statusCode))")
                    streamErrorHandled = true

                    if streamError.message.lowercased().contains("not found") {
                        self.notFound = true
                    } else {
                        self.errorMessage = streamError.message
                    }

                    let endTime = Date().timeIntervalSince1970
                    let totalLatency = (endTime - startTime) * 1000

                    if streamError.message.lowercased().contains("not found") {
                        PostHogSDK.shared.capture("Barcode Analysis Failed - Product Not Found", properties: [
                            "request_id": requestId,
                            "client_activity_id": self.clientActivityId,
                            "barcode": self.barcode,
                            "total_latency_ms": totalLatency
                        ])
                    } else {
                        PostHogSDK.shared.capture("Barcode Analysis Failed - Error", properties: [
                            "request_id": requestId,
                            "client_activity_id": self.clientActivityId,
                            "barcode": self.barcode,
                            "error": streamError.message,
                            "total_latency_ms": totalLatency
                        ])
                    }
                }
            )
        } catch {
            if !streamErrorHandled {
                print("[BarcodeAnalysisView] catch error=\(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
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
    let viewModel: BarcodeAnalysisViewModel

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState
    @Environment(CheckTabState.self) var checkTabState
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
        @Bindable var viewModelBindable = viewModel
        Group {
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
        ScrollView {
            FlowLayout(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(decoratedFragments.enumerated()), id: \.offset) { _, fragment in
                    TappableTextFragment(fragment: fragment)
                }
            }
            .padding()
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
