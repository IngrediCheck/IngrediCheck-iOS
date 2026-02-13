import SwiftUI
import Combine
import SimpleToast
import os

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
        .background(Color.pageBackground)
    }
}

@MainActor struct RecentScansPageView: View {

    @State private var isSearching: Bool = false
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
        .background(Color.pageBackground)
    }

    private var filteredScans: [DTO.Scan] {
        guard let scans = appState.listsTabState.scans else { return [] }
        switch selectedFilter {
        case .all:
            return scans
        case .favorites:
            return scans.filter { $0.is_favorited == true }
        }
    }

    var defaultView: some View {
        Group {
            if let scans = appState.listsTabState.scans, !scans.isEmpty {
                if filteredScans.isEmpty {
                    // Scans exist but filter returns empty (e.g., no favorites)
                    EmptyStateView(
                        imageName: "history-emptystate",
                        title: "No Favorites Yet!",
                        description: [
                            "Products you favorite will appear here.",
                            "Tap the heart icon on any scan to save it."
                        ],
                        buttonTitle: nil,
                        buttonAction: nil
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredScans.enumerated()), id: \.element.id) { index, scan in
                                NavigationLink(value: HistoryRouteItem.scan(scan)) {
                                    RecentScanCard(
                                        scan: scan,
                                        onFavoriteToggle: { scanId, isFavorited in
                                            handleFavoriteToggle(scanId: scanId, isFavorited: isFavorited)
                                        },
                                        onScanUpdated: { updatedScan in
                                            handleScanUpdated(updatedScan: updatedScan)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    // Load more when reaching the end (3 rows remaining)
                                    if index >= filteredScans.count - 3 {
                                        Task {
                                            await scanHistoryStore.loadMore()
                                            appState.listsTabState.scans = scanHistoryStore.scans
                                        }
                                    }
                                }
                            }

                            // Loading indicator at the bottom
                            if scanHistoryStore.isLoading && scanHistoryStore.hasMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        Log.debug("RecentScansPageView", "Pull-to-refresh triggered")
                        await scanHistoryStore.loadHistory(limit: 20, offset: 0, forceRefresh: true)
                        appState.listsTabState.scans = scanHistoryStore.scans
                    }
                }
            } else if scanHistoryStore.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading scans...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                EmptyStateView(
                    imageName: "history-emptystate",
                    title: "No Scans !",
                    description: [
                        "Your recent scans will appear here once",
                        "you start scanning products."
                    ],
                    buttonTitle: "Start Scanning",
                    buttonAction: {
                        appState.navigate(to: .scanCamera(initialMode: nil, initialScanId: nil))
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Recent Scans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FilterSegmentedControl(selection: $selectedFilter)
            }
        }
        .task {
            if appState.listsTabState.scans == nil || appState.listsTabState.scans?.isEmpty == true {
                if scanHistoryStore.isLoading {
                    while scanHistoryStore.isLoading {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                } else if scanHistoryStore.scans.isEmpty {
                    await scanHistoryStore.loadHistory(limit: 20, offset: 0)
                }
                await MainActor.run {
                    appState.listsTabState.scans = scanHistoryStore.scans
                }
            }
        }
    }

    // MARK: - Actions

    private func handleFavoriteToggle(scanId: String, isFavorited: Bool) {
        // Update in store
        let scan = appState.listsTabState.scans?.first { $0.id == scanId }
        if let scan = scan {
            let updatedScan = DTO.Scan(
                id: scan.id,
                scan_type: scan.scan_type,
                barcode: scan.barcode,
                state: scan.state,
                product_info: scan.product_info,
                product_info_source: scan.product_info_source,
                product_info_vote: scan.product_info_vote,
                analysis_result: scan.analysis_result,
                images: scan.images,
                latest_guidance: scan.latest_guidance,
                created_at: scan.created_at,
                last_activity_at: scan.last_activity_at,
                is_favorited: isFavorited,
                analysis_id: scan.analysis_id
            )
            scanHistoryStore.upsertScan(updatedScan)

            // Sync to AppState
            if var scans = appState.listsTabState.scans,
               let idx = scans.firstIndex(where: { $0.id == scanId }) {
                scans[idx] = updatedScan
                appState.listsTabState.scans = scans
            }
        }
    }

    private func handleScanUpdated(updatedScan: DTO.Scan) {
        // Update scan in store
        scanHistoryStore.upsertScan(updatedScan)

        // Sync to AppState
        if var scans = appState.listsTabState.scans,
           let idx = scans.firstIndex(where: { $0.id == updatedScan.id }) {
            scans[idx] = updatedScan
            appState.listsTabState.scans = scans
        }
    }
}

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
            Log.debug("ScanHistorySearch", "Searching for \(searchText)")
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

struct FavoriteItemDetailView: View {
    let item: DTO.ListItem

    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences

    var body: some View {
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
