import SwiftUI
import Combine
import SimpleToast

@MainActor struct ListsTab: View {
    
    @State private var isSearching: Bool = false

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService

    var body: some View {
        @Bindable var appState = appState
        NavigationStack(path: $appState.listsTabState.routes) {
            Group {
                if isSearching {
                    ScanHistorySearchingView(webService: webService, isSearching: $isSearching)
                } else {
                    defaultView
                }
            }
            .navigationDestination(for: HistoryRouteItem.self) { item in
                switch item {
                case .historyItem(let item):
                    HistoryItemDetailView(item: item)
                case .listItem(let item):
                    FavoriteItemDetailView(item: item)
                case .favoritesAll:
                    FavoritesPageView()
                case .recentScansAll:
                    RecentScansPageView()
                }
            }
        }
        .animation(.default, value: isSearching)
    }

    var defaultView: some View {
        VStack {
            FavoritesView()
                .padding(.bottom)
                .padding(.bottom)
            RecentScansView()
            Spacer()
        }
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitle("Lists")
        .toolbar {
            Group {
                if let historyItems = appState.listsTabState.historyItems,
                   historyItems.count > 4 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            isSearching = true
                        }, label: {
                            Image(systemName: "magnifyingglass")
                        })
                    }
                }
            }
        }
    }
}

@MainActor struct FavoritesPageView: View {
    
    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    
    var body: some View {
        Group {
            if let favoriteItems = appState.listsTabState.listItems {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(favoriteItems.enumerated()), id: \.element.list_item_id) { index, item in
                            NavigationLink(value: HistoryRouteItem.listItem(item)) {
                                FavoriteItemCardView(item: item)
                            }
                            .foregroundStyle(.primary)

                            if index != favoriteItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal)
                .padding(.top)
                .refreshable {
                    if let listItems = try? await webService.getFavorites() {
                        appState.listsTabState.listItems = listItems
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitle("Favorites")
    }
}

@MainActor struct FavoritesView: View {

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService

    var body: some View {
        
        VStack {
            HStack {
                Text("Favorites")
                    .font(.headline)
                Spacer()
                if let favoriteItems = appState.listsTabState.listItems,
                   !favoriteItems.isEmpty {
                    NavigationLink(value: HistoryRouteItem.favoritesAll) {
                        Text("View all")
                    }
                }
            }
            .padding(.bottom)
            
            if let favoriteItems = appState.listsTabState.listItems {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(favoriteItems, id: \.list_item_id) { item in
                            NavigationLink(value: HistoryRouteItem.listItem(item)) {
                                FavoriteItemBirdsEyeView(item: item)
                            }
                        }
                    }
                }
                .frame(minHeight: 130)
                .scrollIndicators(.hidden)
                .refreshable {
                    if let listItems = try? await webService.getFavorites() {
                        appState.listsTabState.listItems = listItems
                    }
                }
                .overlay  {
                    if favoriteItems.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    ForEach (0..<1) { index in
                                        Image("EmptyList")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                Text("No Favorite products yet")
                                    .font(.subheadline)
                                    .fontWeight(.light)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 130)
            }
        }
    }
}

@MainActor struct RecentScansPageView: View {

    @State private var isSearching: Bool = false

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if isSearching {
                ScanHistorySearchingView(webService: webService, isSearching: $isSearching)
                    .navigationBarBackButtonHidden()
            } else {
                defaultView
            }
        }
    }
    
    var defaultView: some View {
        Group {
            if let historyItems = appState.listsTabState.historyItems {
                RecentScansListView(historyItems: historyItems)
                    .refreshable {
                        if let history = try? await webService.fetchHistory() {
                            appState.listsTabState.historyItems = history
                        }
                    }
                    .padding(.top)
            }
        }
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Recent Scans")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image("back-arrow1")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .padding(.leading, 5)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    isSearching = true
                }, label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black)
                        .frame(width: 24, height: 24)
                })
            }
        }
    }
}

@MainActor struct RecentScansView: View {

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    
    var showViewAll: Bool {
        if let historyItems = appState.listsTabState.historyItems {
            return historyItems.count > 4
        }
        return false
    }

    var body: some View {
        VStack {
            HStack {
                Text("Recent Scans")
                    .font(.headline)
                Spacer()
                if showViewAll {
                    NavigationLink(value: HistoryRouteItem.recentScansAll) {
                        Text("View all")
                    }
                }
            }
            .padding(.bottom)
            
            if let historyItems = appState.listsTabState.historyItems {
                RecentScansListView(historyItems: historyItems)
                .frame(maxWidth: .infinity)
                .refreshable {
                    if let history = try? await webService.fetchHistory() {
                        appState.listsTabState.historyItems = history
                    }
                }
                .overlay {
                    if historyItems.isEmpty {
                        VStack {
                            Spacer()
                            Image("EmptyRecentScans")
                                .resizable()
                                .scaledToFit()
                            Text("No products scanned yet")
                                .font(.subheadline)
                                .fontWeight(.light)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.gray)
                                .padding(.top)
                            Spacer()
                        }
                        .frame(width: UIScreen.main.bounds.width / 2)
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

@MainActor struct RecentScansListView: View {
    
    var historyItems: [DTO.HistoryItem]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(historyItems.enumerated()), id: \.element.client_activity_id) { index, item in
                    NavigationLink {
                        let product = DTO.Product(
                            barcode: item.barcode,
                            brand: item.brand,
                            name: item.name,
                            ingredients: item.ingredients,
                            images: item.images
                        )
                        ProductDetailView(
                            product: product,
                            matchStatus: item.calculateMatch(),
                            ingredientRecommendations: item.ingredient_recommendations,
                            isPlaceholderMode: false
                        )
                    } label: {
                        HomeRecentScanRow(item: item)
                    }
                    .foregroundStyle(.primary)

                    if index != historyItems.count - 1 {
                        Divider()
                            .padding(.vertical, 14)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

@Observable @MainActor class ScanHistorySearchingViewModel {

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
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
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

@MainActor struct ScanHistorySearchingView: View {

    @Binding var isSearching: Bool

    @State private var vm: ScanHistorySearchingViewModel

    @Environment(AppState.self) var appState
    
    init(webService: WebService, isSearching: Binding<Bool>) {
        _vm = State(initialValue: ScanHistorySearchingViewModel(webService: webService))
        _isSearching = isSearching
    }

    var body: some View {
        VStack {
            SearchBar(searchText: $vm.searchText, isSearching: $isSearching)
                .padding(.bottom)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(vm.searchResults.enumerated()), id: \.element.client_activity_id) { index, item in
                        NavigationLink {
                            let product = DTO.Product(
                                barcode: item.barcode,
                                brand: item.brand,
                                name: item.name,
                                ingredients: item.ingredients,
                                images: item.images
                            )
                            ProductDetailView(
                                product: product,
                                matchStatus: item.calculateMatch(),
                                ingredientRecommendations: item.ingredient_recommendations,
                                isPlaceholderMode: false
                            )
                        } label: {
                            HomeRecentScanRow(item: item)
                        }
                        .foregroundStyle(.primary)

                        if index != vm.searchResults.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
            .overlay {
                if !vm.searchText.isEmpty && vm.searchResults.isEmpty {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass")
                }
            }
            .refreshable {
                vm.refreshSearchResults()
            }
        }
        .padding(.horizontal)
    }
}
struct HistoryItemCardView: View {
    let item: DTO.HistoryItem
    
    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService
    
    var placeholderImage: some View {
        Image("EmptyList")
            .resizable()
            .scaledToFill()
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
                    .font(.callout)

                Text(item.name ?? "Unknown Name")
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
                
                if let dateString = item.convertISODateToLocalDateString() {
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Circle()
                .fill(item.toColor())
                .frame(width: 10, height: 10)
                .padding(.leading)
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

struct FavoriteItemCardView: View {
    let item: DTO.ListItem
    
    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService
    
    var placeholderImage: some View {
        Image("EmptyList")
            .resizable()
            .scaledToFill()
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

                Text(item.name ?? "Unknown Name")
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()

                if let dateString = item.convertISODateToLocalDateString() {
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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

struct FavoriteItemBirdsEyeView: View {
    let item: DTO.ListItem
    
    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService
    
    var placeholderImage: some View {
        Image("EmptyList")
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var body: some View {
        ZStack {
            placeholderImage
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
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
