import SwiftUI
import Combine
import SimpleToast
import os

@MainActor struct ListsTab: View {

    @State private var isSearching: Bool = false

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(ScanHistoryStore.self) var scanHistoryStore

    var body: some View {
        @Bindable var appState = appState
        NavigationStack(path: $appState.listsTabState.routes) {
            Group {
                if isSearching {
                    ScanHistorySearchingView(webService: webService, scanHistoryStore: scanHistoryStore, isSearching: $isSearching)
                } else {
                    defaultView
                }
            }
            .navigationDestination(for: HistoryRouteItem.self) { item in
                switch item {
                case .scan(let scan):
                    let product = scan.toProduct()
                    let recommendations = scan.analysis_result?.toIngredientRecommendations()
                    ProductDetailView(
                        scanId: scan.id,
                        initialScan: scan,
                        product: product,
                        matchStatus: scan.toProductRecommendation(),
                        ingredientRecommendations: recommendations,
                        isPlaceholderMode: false,
                        presentationSource: .homeView
                    )
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
                if let scans = appState.listsTabState.scans,
                   scans.count > 4 {
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
    @State private var isShowingFilterMenu: Bool = false

    private enum RecentScansFilter {
        case all
        case favorites
    }

    @State private var selectedFilter: RecentScansFilter = .all

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if isSearching {
                ScanHistorySearchingView(webService: webService, scanHistoryStore: scanHistoryStore, isSearching: $isSearching)
                    .navigationBarBackButtonHidden()
            } else {
                defaultView
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Image(systemName: "chevron.left")
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
                .accessibilityAddTraits(.isButton)

           

            Text("Recent Scans")
                .font(ManropeFont.semiBold.size(18))
                .foregroundStyle(.grayScale150)
                .padding(.leading , 12)

            Spacer()

            Image("filter")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.trailing, 2)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    isShowingFilterMenu.toggle()
                }
                .accessibilityAddTraits(.isButton)
        }
//        .padding(.horizontal, 20)
     
        .background(Color.white)
    }
    
    var defaultView: some View {
        Group {
            if let scans = appState.listsTabState.scans, !scans.isEmpty {
                // Apply filter if favorites is selected
                let filteredScans: [DTO.Scan] = {
                    switch selectedFilter {
                    case .all:
                        return scans
                    case .favorites:
                        return scans.filter { $0.is_favorited == true }
                    }
                }()
                
                RecentScansListView(scans: filteredScans)
                    .refreshable {
                        // Load via store (single source of truth)
                        await scanHistoryStore.loadHistory(limit: 20, offset: 0, forceRefresh: true)
                        // Sync to AppState for backwards compatibility
                        appState.listsTabState.scans = scanHistoryStore.scans
                    }
                    .padding(.top)
            } else if scanHistoryStore.isLoading {
                // Show loading indicator while loading
                VStack {
                    Spacer()
                    ProgressView("Loading scans...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Empty state
                VStack {
                    Spacer()
                    Text("No recent scans")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Load scan history when view appears if not already loaded
            if appState.listsTabState.scans == nil || appState.listsTabState.scans?.isEmpty == true {
                // Wait if store is currently loading
                if scanHistoryStore.isLoading {
                    while scanHistoryStore.isLoading {
                        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                    }
                } else if scanHistoryStore.scans.isEmpty {
                    // Load from API if store is empty
                    await scanHistoryStore.loadHistory(limit: 20, offset: 0)
                }
                // Sync store data to AppState
                await MainActor.run {
                    appState.listsTabState.scans = scanHistoryStore.scans
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isShowingFilterMenu {
                ZStack(alignment: .topTrailing) {
                    Color.black
                        .opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isShowingFilterMenu = false
                        }

                    VStack(spacing: 0) {
                        Button {
                            selectedFilter = .all
                            isShowingFilterMenu = false
                        } label: {
                            HStack {
                                Text("All")
                                    .font(ManropeFont.regular.size(20))
                                    .foregroundStyle(.grayScale150)
                                Spacer()
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedFilter = .favorites
                            isShowingFilterMenu = false
                        } label: {
                            HStack {
                                Text("Favorites")
                                    .font(ManropeFont.regular.size(20))
                                    .foregroundStyle(.grayScale150)
                                Spacer()
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .background(Color.grayScale20)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 210)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.grayScale30, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
                    .padding(.top, 8)
                    .padding(.trailing, 6)
                }
            }
        }
    }
}

@MainActor struct RecentScansView: View {

    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    
    var showViewAll: Bool {
        if let scans = appState.listsTabState.scans {
            return scans.count > 4
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
            
            if let scans = appState.listsTabState.scans {
                RecentScansListView(scans: scans)
                .frame(maxWidth: .infinity)
                .refreshable {
                    // Load via store (single source of truth)
                    await scanHistoryStore.loadHistory(limit: 20, offset: 0, forceRefresh: true)
                    // Sync to AppState for backwards compatibility
                    appState.listsTabState.scans = scanHistoryStore.scans
                }
                .overlay {
                    if scans.isEmpty {
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
    
    var scans: [DTO.Scan]
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    @Environment(AppState.self) var appState
    @State private var isCameraPresented: Bool = false
    
    var body: some View {
        Group {
            if scans.isEmpty {
                VStack {
                    ZStack(alignment: .bottom) {
                        Image("history-emptystate")
                            .resizable()
                            .scaledToFit()

                        VStack(spacing: 0) {
                            Text("No Scans !")
                                .font(ManropeFont.bold.size(16))
                                .foregroundStyle(.grayScale150)

                            Text("Your recent scans will appear here once")
                                .font(ManropeFont.regular.size(13))
                                .foregroundStyle(.grayScale100)
                                .multilineTextAlignment(.center)

                            Text("you start scanning products.")
                                .font(ManropeFont.regular.size(13))
                                .foregroundStyle(.grayScale100)
                                .multilineTextAlignment(.center)

                            Button {
                                isCameraPresented = true
                            } label: {
                                GreenCapsule(
                                    title: "Start Scanning",
                                    width: 159,
                                    height: 52,
                                    takeFullWidth: false,
                                    labelFont: ManropeFont.bold.size(16)
                                )
                            }
                            .padding(.top,24)
                            .buttonStyle(.plain)
                        }
                        .offset(y: -UIScreen.main.bounds.height * 0.2)
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                            NavigationLink(value: HistoryRouteItem.scan(scan)) {
                                ScanRow(scan: scan)
                            }
                            .foregroundStyle(.primary)
                            .onAppear {
                                // Load more when reaching the end (3 rows remaining)
                                if index >= scans.count - 3 {
                                    Task {
                                        await scanHistoryStore.loadMore()
                                        // Sync to AppState for backwards compatibility
                                        appState.listsTabState.scans = scanHistoryStore.scans
                                    }
                                }
                            }

                            if index != scans.count - 1 {
                                Divider()
                                    .padding(.vertical, 14)
                            }
                        }
                        
                        // Loading indicator at the bottom
                        if scanHistoryStore.isLoading && scanHistoryStore.hasMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            ScanCameraView()
        }
    }
}

//#Preview {
//    RecentScansListView()
//        .environment(AppState())
//}

@Observable @MainActor class ScanHistorySearchingViewModel {

    let webService: WebService
    let scanHistoryStore: ScanHistoryStore

    var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
        }
    }

    var searchResults: [DTO.Scan] = []

    private var searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(webService: WebService, scanHistoryStore: ScanHistoryStore) {
        self.webService = webService
        self.scanHistoryStore = scanHistoryStore
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
            Log.debug("ListsTab", "Searching for \(searchText)")
            // Load from store and filter client-side
            await scanHistoryStore.loadHistory(limit: 100, offset: 0, forceRefresh: true)

            let filtered = scanHistoryStore.scans.filter { scan in
                let name = scan.product_info.name?.lowercased() ?? ""
                let brand = scan.product_info.brand?.lowercased() ?? ""
                let query = searchText.lowercased()
                return name.contains(query) || brand.contains(query)
            }
            await MainActor.run {
                self.searchResults = filtered
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

    init(webService: WebService, scanHistoryStore: ScanHistoryStore, isSearching: Binding<Bool>) {
        _vm = State(initialValue: ScanHistorySearchingViewModel(webService: webService, scanHistoryStore: scanHistoryStore))
        _isSearching = isSearching
    }

    var body: some View {
        VStack {
            SearchBar(searchText: $vm.searchText, isSearching: $isSearching)
                .padding(.bottom)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(vm.searchResults.enumerated()), id: \.element.id) { index, scan in
                        NavigationLink(value: HistoryRouteItem.scan(scan)) {
                            ScanRow(scan: scan)
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
                        images: item.images,
                        claims: nil
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

struct ScanDetailView: View {
    let scan: DTO.Scan
    
    @State private var feedbackData = FeedbackData()
    @State private var showToast: Bool = false

    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences
    
    private func submitFeedback() {
        Task {
            // Note: clientActivityId is not available in Scan, so feedback submission would need scan.id
            // For now, leaving as placeholder
            Log.debug("ListsTab", "Feedback submission not yet implemented for Scan")
        }
    }
    
    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        let product = scan.toProduct()
        let imageLocations: [DTO.ImageLocationInfo] = scan.product_info.images?.compactMap { scanImageInfo in
            guard let urlString = scanImageInfo.url,
                  let url = URL(string: urlString) else {
                return nil
            }
            return .url(url)
        } ?? []
        
        ScrollView {
            VStack(spacing: 15) {
                if let name = scan.product_info.name {
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                if let brand = scan.product_info.brand {
                    Text(brand)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                ProductImagesView(images: imageLocations) {
                    appState.feedbackConfig = FeedbackConfig(
                        feedbackData: $feedbackData,
                        feedbackCaptureOptions: .imagesOnly,
                        onSubmit: {
                            showToast.toggle()
                            submitFeedback()
                        }
                    )
                }
                if scan.product_info.ingredients.isEmpty {
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
                    let recommendations = scan.analysis_result?.toIngredientRecommendations()
                    AnalysisResultView(product: product, ingredientRecommendations: recommendations)
                    
                    HStack {
                        Text("Ingredients").font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)

                    IngredientsText(ingredients: scan.product_info.ingredients, ingredientRecommendations: recommendations)
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
                if !imageLocations.isEmpty && !scan.product_info.ingredients.isEmpty {
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
                // Note: StarButton needs clientActivityId which is not in Scan - would need to be handled differently
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
                    images: item.images,
                    claims: nil
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
