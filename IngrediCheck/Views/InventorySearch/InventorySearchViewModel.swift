import Foundation
import Combine

struct InventorySearchResult: Identifiable {
    let id: String
    let product: MockInventoryProduct
    let scan: DTO.Scan
    let recommendation: DTO.ProductRecommendation
}

@Observable
@MainActor
final class InventorySearchViewModel {

    var searchText: String = "" {
        didSet { searchTextSubject.send(searchText) }
    }

    var selectedCategory: MockInventoryCategory?
    var selectedMatchFilter: MatchFilter = .all

    enum MatchFilter: String, CaseIterable {
        case all = "All"
        case matched = "Matched"
        case uncertain = "Uncertain"
        case unmatched = "Unmatched"
    }

    private(set) var filteredResults: [InventorySearchResult] = []

    // Cache: keyed by food notes hash to avoid recomputation
    private var cachedResults: [InventorySearchResult] = []
    private var cachedFoodNoteSections: [String]?

    private var searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var debouncedSearchText: String = ""

    init() {
        searchTextSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.debouncedSearchText = text
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    func loadProducts(foodNoteSections: [String]) {
        if cachedFoodNoteSections == nil || cachedFoodNoteSections != foodNoteSections {
            cachedFoodNoteSections = foodNoteSections
            cachedResults = MockInventoryData.allProducts.map { product in
                let scan = MockInventoryData.generateMockScan(for: product, foodNoteSections: foodNoteSections)
                let recommendation = scan.toProductRecommendation()
                return InventorySearchResult(
                    id: product.id,
                    product: product,
                    scan: scan,
                    recommendation: recommendation
                )
            }
        }
        applyFilters()
    }

    func applyFilters() {
        var results = cachedResults

        // Filter by search text
        let query = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            results = results.filter {
                $0.product.name.lowercased().contains(query) ||
                $0.product.brand.lowercased().contains(query)
            }
        }

        // Filter by category
        if let category = selectedCategory {
            results = results.filter { $0.product.category == category }
        }

        // Filter by match status
        switch selectedMatchFilter {
        case .all:
            break
        case .matched:
            results = results.filter { $0.recommendation == .match || $0.recommendation == .noPreferences }
        case .uncertain:
            results = results.filter { $0.recommendation == .needsReview }
        case .unmatched:
            results = results.filter { $0.recommendation == .notMatch }
        }

        filteredResults = results
    }
}
