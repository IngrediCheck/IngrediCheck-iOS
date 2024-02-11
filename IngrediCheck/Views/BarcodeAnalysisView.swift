import SwiftUI

struct HeaderImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            ProgressView()
        }
        .clipped()
    }
}

struct DownvoteButton: View {
    @Binding var rating: Int

    func buttonImage(systemName: String, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .frame(width: 20, height: 20)
            .font(.title3.weight(.thin))
            .foregroundColor(foregroundColor)
    }
    
    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == -1) ? 0 : -1
            }
        }, label: {
            buttonImage(
                systemName: rating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                foregroundColor: .red
            )
        })
    }
}

struct UpvoteButton: View {
    @Binding var rating: Int

    func buttonImage(systemName: String, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .frame(width: 20, height: 20)
            .font(.title3.weight(.thin))
            .foregroundColor(foregroundColor)
    }

    var body: some View {
        Button(action: {
            withAnimation {
                self.rating = (self.rating == 1) ? 0 : 1
            }
        }, label: {
            buttonImage(
                systemName: rating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup",
                foregroundColor: .green
            )
        })
    }
}

@Observable class BarcodeAnalysisViewModel {
    let barcode: String
    let webService: WebService
    let userPreferences: UserPreferences
    
    init(barcode: String, webService: WebService, userPreferences: UserPreferences) {
        self.barcode = barcode
        self.webService = webService
        self.userPreferences = userPreferences
    }

    var product: DTO.Product?
    var notFound: Bool?
    var errorMessage: String?
    var ingredientRecommendations: [DTO.IngredientRecommendation]?
    let clientActivityId = UUID().uuidString
    
    func analyze() async {
        
        do {
            product = try await webService.fetchProductDetailsFromBarcode(barcode: barcode)
            
            let result =
                try await webService.fetchIngredientRecommendations(
                    clientActivityId: clientActivityId,
                    userPreferenceText: userPreferences.asString,
                    barcode: barcode
                )

            withAnimation {
                ingredientRecommendations = result
            }
            
        } catch NetworkError.notFound {
            self.notFound = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func submitRating(rating: Int) async {
        try? await webService.rateAnalysis(clientActivityId: clientActivityId, rating: rating)
    }
}

struct BarcodeAnalysisView: View {
    
    @Binding var routes: [CapturedItem]
    @Binding var captureSelection: CaptureSelectionType
    @Binding var barcode: String?

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    
    @State private var rating: Int = 0
    @State private var viewModel: BarcodeAnalysisViewModel?

    var body: some View {
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
                            captureSelection = .ingredients
                            _ = routes.popLast()
                        }, label: {
                            Text("Click here to add Photos")
                        })
                        .padding(.top)
                    }
                } else if let product = viewModel.product {
                    ScrollView {
                        VStack(spacing: 20) {
                            if case let .url(url) = product.images.first {
                                HeaderImage(url: url)
                            }
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
