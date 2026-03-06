import SwiftUI

struct InventorySearchView: View {
    @Environment(FoodNotesStore.self) private var foodNotesStore
    @State private var viewModel = InventorySearchViewModel()
    @State private var isSearchActive = false

    private var hasNoFoodNotes: Bool {
        foodNotesStore.hasNoFoodNotes
    }

    private var foodNoteSections: [String] {
        guard !hasNoFoodNotes else { return [] }
        return Array(foodNotesStore.canvasPreferences.sections.keys)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search bar
                searchBarSection

                // Category chips
                categoryChipsSection

                // Match filter
                matchFilterSection

                // Food notes prompt
                if hasNoFoodNotes {
                    AddFoodNotesPromptCard()
                        .padding(.horizontal, 20)
                }

                // Results
                if viewModel.filteredResults.isEmpty {
                    emptyStateView
                } else {
                    resultsListSection
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#FAFAFA"))
        .navigationTitle("Discover Products")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadProducts(foodNoteSections: foodNoteSections)
        }
        .onChange(of: foodNotesStore.canvasPreferences) { _, _ in
            viewModel.loadProducts(foodNoteSections: foodNoteSections)
        }
    }

    // MARK: - Search Bar

    private var searchBarSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search products...", text: $viewModel.searchText)
                    .font(ManropeFont.regular.size(14))

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "multiply.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Category Chips

    private var categoryChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                    viewModel.applyFilters()
                }

                ForEach(MockInventoryCategory.allCases) { category in
                    CategoryChip(title: category.rawValue, isSelected: viewModel.selectedCategory == category) {
                        viewModel.selectedCategory = category
                        viewModel.applyFilters()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Match Filter

    private var matchFilterSection: some View {
        HStack(spacing: 0) {
            ForEach(InventorySearchViewModel.MatchFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedMatchFilter = filter
                        viewModel.applyFilters()
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(ManropeFont.medium.size(13))
                        .foregroundStyle(viewModel.selectedMatchFilter == filter ? .white : .grayScale100)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedMatchFilter == filter
                            ? Capsule().fill(Color.primary600)
                            : Capsule().fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.grayScale30)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Results

    private var resultsListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredResults) { result in
                NavigationLink(value: AppRoute.productDetail(scanId: result.scan.id, initialScan: result.scan)) {
                    InventoryProductCard(
                        product: result.product,
                        matchStatus: hasNoFoodNotes ? .noPreferences : result.recommendation
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.grayScale60)

            Text("No products found")
                .font(ManropeFont.semiBold.size(16))
                .foregroundStyle(.grayScale100)

            Text("Try adjusting your search or filters")
                .font(ManropeFont.regular.size(13))
                .foregroundStyle(.grayScale80)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
