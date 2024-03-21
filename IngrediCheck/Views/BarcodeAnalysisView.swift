import SwiftUI
import SwiftUIFlowLayout
import SimpleToast

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

struct FlagButton: View {
    @Binding var rating: Int

    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == -1) ? 0 : -1
            }
        }, label: {
            Image(systemName: rating == -1 ? "flag.fill" : "flag")
                .font(.subheadline)

        })
    }
}

@Observable class BarcodeAnalysisViewModel {

    let barcode: String
    let webService: WebService
    let userPreferences: UserPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(_ barcode: String, _ webService: WebService, _ userPreferences: UserPreferences) {
        self.barcode = barcode
        self.webService = webService
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
                    userPreferenceText: userPreferences.asString,
                    barcode: barcode)

            await MainActor.run {
                withAnimation {
                    self.ingredientRecommendations = result
                }
            }
            
        } catch NetworkError.notFound {
            await MainActor.run {
                self.notFound = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
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
    
    @Binding var barcode: String?

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState
    
    @State private var viewModel: BarcodeAnalysisViewModel?
    @State private var showToast: Bool = false

    private let toastOptions = SimpleToastOptions(
        hideAfter: 2
    )

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
                _ = appState.checkTabState.routes.popLast()
            }, label: {
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                        .padding()
                    Text("Upload a photo")
                        .foregroundStyle(.paletteAccent)
                        .font(.headline)
                }
                .frame(width: UIScreen.main.bounds.width - 110)
                .frame(height: UIScreen.main.bounds.width - 110)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.gray.opacity(0.1))
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
                                    appState.activeSheet = .feedback(FeedbackConfig(
                                        feedbackData: $viewModelBindable.feedbackData,
                                        feedbackCaptureOptions: .imagesOnly,
                                        onSubmit: {
                                            showToast.toggle()
                                            viewModel.submitFeedback()
                                        }
                                    ))
                                }
                                
                                if product.ingredients.isEmpty {
                                    Text("Help! Our Product Database is missing an Ingredient List for this Product. Submit Product Images and Earn IngrediPoiints\u{00A9}!")
                                        .font(.subheadline)
                                        .padding()
                                        .multilineTextAlignment(.center)
                                    Button(action: {
                                        userPreferencesBindable.captureType = .ingredients
                                        _ = appState.checkTabState.routes.popLast()
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
                        .simpleToast(isPresented: $showToast, options: toastOptions) {
                            Text("Thank you! 🙏")
                            .padding()
                            .padding(.horizontal)
                            .background(Color.green.opacity(0.6))
                            .foregroundColor(Color.white)
                            .cornerRadius(10)
                            .padding(.top)
                        }
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
                                    if !product.images.isEmpty && !product.ingredients.isEmpty {
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
                                    StarButton(clientActivityId: viewModel.clientActivityId, favorited: false)
//                                    UpvoteButton(rating: $viewModelBindable.feedbackData.rating)
                                    FlagButton(rating: $viewModelBindable.feedbackData.rating)
                                }
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
                ProgressView()
                    .task {
                        let newViewModel = BarcodeAnalysisViewModel(barcode!, webService, userPreferences)
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
                .underline(true, pattern: .dot)
                .background(
                    .yellow.opacity(0.15)
                )
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
                .underline(true, pattern: .dot)
                .background(
                    .red.opacity(0.15)
                )
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
