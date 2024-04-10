import SwiftUI
import Combine
import SimpleToast

struct HistoryTab: View {

    @Environment(UserPreferences.self) var userPreferences
    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService

    var body: some View {
        @Bindable var appStateBindable = appState
        @Bindable var userPreferencesBindable = userPreferences
        NavigationStack(path: $appStateBindable.historyTabState.routes) {
            VStack {
                if userPreferences.historyType == .scans {
                    ScanHistoryView(webService: webService)
                } else {
                    FavoritesView(webService: webService)
                }
            }
            .animation(.default, value: userPreferences.historyType)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Options", selection: $userPreferencesBindable.historyType) {
                        Text("Scans").tag(HistoryType.scans)
                        Text("Favorites").tag(HistoryType.favorites)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onAppear {
                        UISegmentedControl.appearance().selectedSegmentTintColor = .paletteAccent
                    }
                    .frame(width: (UIScreen.main.bounds.width * 2) / 3)
                }
            }
            .navigationDestination(for: HistoryRouteItem.self) { item in
                switch item {
                case .historyItem(let item):
                    HistoryItemDetailView(item: item)
                case .listItem(let item):
                    FavoriteItemDetailView(item: item)
                }
            }
        }
    }
}

@Observable @MainActor class ScanHistoryViewModel {
    
    let webService: WebService

    var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
        }
    }

    var searchResults: [DTO.HistoryItem] = []

    private var searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(webService: WebService) {
        self.webService = webService
        searchTextSubject
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.searchForEntries(searchText: text)
            }
            .store(in: &cancellables)
    }
    
    private func searchForEntries(searchText: String) {
        guard !searchText.isEmpty  else {
            DispatchQueue.main.async {
                self.searchResults = []
            }
            return
        }

        Task {
            print("Searching for \(searchText)")
            let newSearchResults = try await webService.fetchHistory(searchText: searchText)
            await MainActor.run {
                self.searchResults = newSearchResults
            }
        }
    }
    
    func refreshSearchResults() {
        searchForEntries(searchText: searchText)
    }
}

@MainActor struct ScanHistoryView: View {
    let webService: WebService
    @State private var viewModel: ScanHistoryViewModel

    init(webService: WebService) {
        self.webService = webService
        _viewModel = State(initialValue: ScanHistoryViewModel(webService: webService))
    }

    var body: some View {
        SearchableScanHistoryView(viewModel: viewModel)
            .searchable(text: $viewModel.searchText, placement: .automatic, prompt: "Type to search")
    }
}

struct SearchableScanHistoryView: View {
    
    let viewModel: ScanHistoryViewModel
    
    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        if isSearching {
            List {
                ForEach(viewModel.searchResults, id:\.client_activity_id) { item in
                    Button {
                        appState.historyTabState.routes.append(.historyItem(item))
                    } label: {
                        HistoryItemCardView(item: item)
                    }
                }
                .listStyle(.inset)
                .refreshable {
                    viewModel.refreshSearchResults()
                }
                .overlay {
                    if !viewModel.searchText.isEmpty && viewModel.searchResults.isEmpty {
                        ContentUnavailableView("No Results", image: "magnifyingglass")
                    }
                }
            }
        } else {
            if let historyItems = appState.historyTabState.historyItems {
                List {
                    ForEach(historyItems, id:\.client_activity_id) { item in
                        Button {
                            appState.historyTabState.routes.append(.historyItem(item))
                        } label: {
                            HistoryItemCardView(item: item)
                        }
                    }
                }
                .listStyle(.inset)
                .refreshable {
                    if let history = try? await webService.fetchHistory() {
                        appState.historyTabState.historyItems = history
                    }
                }
                .overlay {
                    if historyItems.isEmpty {
                        VStack {
                            ContentUnavailableView(
                                "No History yet",
                                systemImage: "tray",
                                description: Text("A list of Packaged Food Items you have Scanned in the past will show up here.")
                            )
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }
}

struct HistoryItemCardView: View {
    let item: DTO.HistoryItem
    
    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService
    
    var placeholderImage: some View {
        Image("EmptyList")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var body: some View {
        HStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                placeholderImage
            }

            VStack(alignment: .leading) {
                Text(item.brand ?? "Unknown Brand")
                    .lineLimit(1)
                    .font(.headline)
                    .padding(.top)
                
                Text(item.name ?? "Unknown Name")
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Circle()
                .fill(item.toColor())
                .frame(width: 10, height: 10)

            Spacer()
        }
        .task {
            if let firstImage = item.images.first,
               let image = try? await webService.fetchImage(imageLocation: firstImage, imageSize: .small) {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}

struct HistoryItemDetailView: View {
    let item: DTO.HistoryItem
    
    @State private var feedbackData: FeedbackData
    @State private var showToast: Bool = false

    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences
    
    init(item: DTO.HistoryItem) {
        self.item = item
        self.feedbackData = FeedbackData(rating: item.rating)
    }

    private func submitFeedback() {
        Task {
            try? await webService.submitFeedback(
                clientActivityId: item.client_activity_id,
                feedbackData: feedbackData
            )
        }
    }
    
    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        ScrollView {
            VStack(spacing: 15) {
                if let name = item.name {
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                if let brand = item.brand {
                    Text(brand)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                ProductImagesView(images: item.images) {
                    appState.feedbackConfig = FeedbackConfig(
                        feedbackData: $feedbackData,
                        feedbackCaptureOptions: .imagesOnly,
                        onSubmit: {
                            showToast.toggle()
                            submitFeedback()
                        }
                    )
                }
                if item.ingredients.isEmpty {
                    Text("Help! Our Product Database is missing an Ingredient List for this Product. Submit Product Images and Earn IngrediPoiints\u{00A9}!")
                        .font(.subheadline)
                        .padding()
                        .multilineTextAlignment(.center)
                    Button(action: {
                        userPreferencesBindable.captureType = .ingredients
                        appState.activeSheet = .scan
                    }, label: {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                    })
                    Text("Product will be analyzed instantly!")
                        .font(.subheadline)
                } else {
                    let product = DTO.Product(
                        barcode: item.barcode,
                        brand: item.brand,
                        name: item.name,
                        ingredients: item.ingredients,
                        images: item.images
                    )
                    AnalysisResultView(product: product, ingredientRecommendations: item.ingredient_recommendations)
                    
                    HStack {
                        Text("Ingredients").font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)

                    IngredientsText(ingredients: product.ingredients, ingredientRecommendations: item.ingredient_recommendations)
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
                if !item.images.isEmpty && !item.ingredients.isEmpty {
                    Button(action: {
                        appState.feedbackConfig = FeedbackConfig(
                            feedbackData: $feedbackData,
                            feedbackCaptureOptions: .imagesOnly,
                            onSubmit: {
                                showToast.toggle()
                                submitFeedback()
                            }
                        )
                    }, label: {
                        Image(systemName: "photo.badge.plus")
                            .font(.subheadline)
                    })
                }
                StarButton(clientActivityId: item.client_activity_id, favorited: item.favorited)
                Button(action: {
                    appState.feedbackConfig = FeedbackConfig(
                        feedbackData: $feedbackData,
                        feedbackCaptureOptions: .feedbackAndImages,
                        onSubmit: {
                            showToast.toggle()
                            submitFeedback()
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

@Observable @MainActor class FavoritesViewModel {
    let webService: WebService
    
    var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
        }
    }

    var searchResults: [DTO.ListItem] = []

    private var searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(webService: WebService) {
        self.webService = webService
        searchTextSubject
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.searchForEntries(searchText: text)
            }
            .store(in: &cancellables)
    }
    
    private func searchForEntries(searchText: String) {
        guard !searchText.isEmpty  else {
            DispatchQueue.main.async {
                self.searchResults = []
            }
            return
        }

        Task {
            print("Searching for \(searchText)")
            let newSearchResults = try await webService.getFavorites(searchText: searchText)
            await MainActor.run {
                self.searchResults = newSearchResults
            }
        }
    }
    
    func refreshSearchResults() {
        searchForEntries(searchText: searchText)
    }
}

@MainActor struct FavoritesView: View {
    let webService: WebService
    @State private var viewModel: FavoritesViewModel

    init(webService: WebService) {
        self.webService = webService
        _viewModel = State(initialValue: FavoritesViewModel(webService: webService))
    }

    var body: some View {
        SearchableFavoritesView(viewModel: viewModel)
            .searchable(text: $viewModel.searchText, placement: .automatic, prompt: "Type to search")
    }
}

struct SearchableFavoritesView: View {

    let viewModel: FavoritesViewModel

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        if isSearching {
            List {
                ForEach(viewModel.searchResults, id:\.list_item_id) { item in
                    Button {
                        appState.historyTabState.routes.append(.listItem(item))
                    } label: {
                        FavoriteItemCardView(item: item)
                    }
                }
                .listStyle(.inset)
                .refreshable {
                    viewModel.refreshSearchResults()
                }
                .overlay {
                    if !viewModel.searchText.isEmpty && viewModel.searchResults.isEmpty {
                        ContentUnavailableView("No Results", image: "magnifyingglass")
                    }
                }
            }
        } else {
            if let listItems = appState.historyTabState.listItems {
                List {
                    ForEach(listItems, id:\.list_item_id) { item in
                        Button {
                            appState.historyTabState.routes.append(.listItem(item))
                        } label: {
                            FavoriteItemCardView(item: item)
                        }
                    }
                }
                .listStyle(.inset)
                .refreshable {
                    if let listItems = try? await webService.getFavorites() {
                        appState.historyTabState.listItems = listItems
                    }
                }
                .overlay {
                    if listItems.isEmpty {
                        VStack {
                            ContentUnavailableView(
                                "No Favorites yet",
                                systemImage: "star",
                                description: Text("You Favorite Packaged Food Items will show up here.")
                            )
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }
}

struct FavoriteItemCardView: View {
    let item: DTO.ListItem
    
    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService
    
    var placeholderImage: some View {
        Image("EmptyList")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var body: some View {
        HStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                placeholderImage
            }

            VStack(alignment: .leading) {
                Text(item.brand ?? "Unknown Brand")
                    .lineLimit(1)
                    .font(.headline)
                    .padding(.top)
                
                Text(item.name ?? "Unknown Name")
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Spacer()
        }
        .task {
            if let firstImage = item.images.first,
               let image = try? await webService.fetchImage(imageLocation: firstImage, imageSize: .small) {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}

struct FavoriteItemDetailView: View {
    let item: DTO.ListItem
    
    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences

    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        ScrollView {
            VStack(spacing: 15) {
                if let name = item.name {
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                if let brand = item.brand {
                    Text(brand)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                ProductImagesView(images: item.images) {
                    // TODO: What does it mean to contribute images to a Favorite item?
                }
                let product = DTO.Product(
                    barcode: item.barcode,
                    brand: item.brand,
                    name: item.name,
                    ingredients: item.ingredients,
                    images: item.images
                )
                
                HStack {
                    Text("Ingredients").font(.headline)
                    Spacer()
                }
                .padding(.horizontal)

                Text(product.ingredientsListAsString)
                    .padding(.horizontal)
            }
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                StarButton(clientActivityId: item.list_item_id, favorited: true)
            }
        }
    }
}
