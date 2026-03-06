import Foundation

// MARK: - Mock Inventory Category

enum MockInventoryCategory: String, CaseIterable, Identifiable {
    case snacks = "Snacks"
    case beverages = "Beverages"
    case dairy = "Dairy"
    case bakery = "Bakery"
    case frozen = "Frozen"
    case condiments = "Condiments"
    case cereals = "Cereals"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .snacks: return "leaf"
        case .beverages: return "cup.and.saucer"
        case .dairy: return "drop"
        case .bakery: return "birthday.cake"
        case .frozen: return "snowflake"
        case .condiments: return "flask"
        case .cereals: return "sun.max"
        }
    }
}

// MARK: - Mock Inventory Product

struct MockInventoryProduct: Identifiable {
    let id: String
    let name: String
    let brand: String
    let barcode: String
    let category: MockInventoryCategory
    let ingredients: [DTO.Ingredient]
    let claims: [String]

    var ingredientNames: [String] {
        flattenIngredientNames(ingredients)
    }

    private func flattenIngredientNames(_ ingredients: [DTO.Ingredient]) -> [String] {
        ingredients.flatMap { ingredient in
            [ingredient.name.lowercased()] + flattenIngredientNames(ingredient.ingredients)
        }
    }
}

// MARK: - Mock Inventory Data

enum MockInventoryData {

    // Keyword map: food note category → ingredient keywords that indicate a conflict
    static let allergenKeywordMap: [String: [String]] = [
        "dairy": ["milk", "whey", "casein", "cream", "butter", "cheese", "lactose", "yogurt", "nonfat milk"],
        "gluten": ["wheat", "flour", "barley", "rye", "malt", "gluten", "semolina", "enriched flour"],
        "nuts": ["peanut", "almond", "cashew", "walnut", "pecan", "hazelnut", "tree nut", "macadamia"],
        "soy": ["soy", "soy lecithin", "soybean", "soy protein", "tofu", "edamame"],
        "eggs": ["egg", "albumin", "egg white", "egg yolk"],
        "shellfish": ["shrimp", "crab", "lobster", "shellfish"],
        "fish": ["fish", "anchovy", "cod", "salmon", "tuna"],
        "sesame": ["sesame", "tahini"],
        "corn": ["corn", "corn syrup", "cornstarch", "corn flour", "high fructose corn syrup"],
        "sugar": ["sugar", "cane sugar", "high fructose corn syrup", "dextrose", "sucrose", "glucose"],
        "artificial": ["artificial", "red 40", "yellow 5", "blue 1", "aspartame", "sucralose", "acesulfame"],
    ]

    static let allProducts: [MockInventoryProduct] = [
        // MATCHED products (generally allergen-free / simple)
        MockInventoryProduct(
            id: "mock-001", name: "Sparkling Water", brand: "La Croix", barcode: "0012993100018",
            category: .beverages,
            ingredients: [ing("Carbonated Water"), ing("Natural Flavor")],
            claims: ["No Calories", "No Sweeteners"]
        ),
        MockInventoryProduct(
            id: "mock-002", name: "Dark Chocolate Bar", brand: "Hu Kitchen", barcode: "0085002200012",
            category: .snacks,
            ingredients: [ing("Organic Cacao"), ing("Organic Coconut Sugar"), ing("Organic Cocoa Butter")],
            claims: ["Paleo", "Vegan", "No Dairy"]
        ),
        MockInventoryProduct(
            id: "mock-003", name: "Almond Flour Crackers", brand: "Simple Mills", barcode: "0085612300019",
            category: .snacks,
            ingredients: [ing("Almond Flour"), ing("Sunflower Seeds"), ing("Flax Seeds"), ing("Sea Salt")],
            claims: ["Gluten Free", "Grain Free"]
        ),
        MockInventoryProduct(
            id: "mock-004", name: "Organic Coconut Water", brand: "Harmless Harvest", barcode: "0088801400011",
            category: .beverages,
            ingredients: [ing("Organic Coconut Water")],
            claims: ["Organic", "No Added Sugar"]
        ),
        MockInventoryProduct(
            id: "mock-005", name: "Sea Salt Chips", brand: "Siete", barcode: "0085501500017",
            category: .snacks,
            ingredients: [ing("Cassava Flour"), ing("Avocado Oil"), ing("Sea Salt"), ing("Coconut Flour")],
            claims: ["Grain Free", "Gluten Free", "Paleo"]
        ),

        // UNCERTAIN products (contain potential allergens like nuts/soy)
        MockInventoryProduct(
            id: "mock-006", name: "Dark Chocolate Nut & Sea Salt Bar", brand: "KIND", barcode: "0060299900014",
            category: .snacks,
            ingredients: [
                ing("Almonds"), ing("Chicory Root Fiber"), ing("Dark Chocolate", sub: ["Chocolate Liquor", "Cane Sugar", "Cocoa Butter", "Soy Lecithin"]),
                ing("Honey"), ing("Peanuts"), ing("Sea Salt")
            ],
            claims: ["Gluten Free"]
        ),
        MockInventoryProduct(
            id: "mock-007", name: "Beyond Burger", brand: "Beyond Meat", barcode: "0085005700018",
            category: .frozen,
            ingredients: [
                ing("Water"), ing("Pea Protein"), ing("Expeller-Pressed Canola Oil"), ing("Refined Coconut Oil"),
                ing("Rice Protein"), ing("Natural Flavors"), ing("Methylcellulose"), ing("Potato Starch")
            ],
            claims: ["Plant-Based", "No Soy", "No Gluten"]
        ),
        MockInventoryProduct(
            id: "mock-008", name: "Chocolate Sea Salt Bar", brand: "RXBar", barcode: "0085007800012",
            category: .snacks,
            ingredients: [ing("Dates"), ing("Egg Whites"), ing("Cashews"), ing("Almonds"), ing("Chocolate"), ing("Cocoa"), ing("Sea Salt"), ing("Natural Flavors")],
            claims: ["No Added Sugar", "Gluten Free"]
        ),
        MockInventoryProduct(
            id: "mock-009", name: "Oat Milk Original", brand: "Oatly", barcode: "0075710900016",
            category: .beverages,
            ingredients: [ing("Oat Base (Water, Oats)"), ing("Rapeseed Oil"), ing("Calcium Carbonate"), ing("Sea Salt"), ing("Vitamins")],
            claims: ["Vegan", "No Dairy"]
        ),
        MockInventoryProduct(
            id: "mock-010", name: "Organic Hummus", brand: "Hope Foods", barcode: "0085509100015",
            category: .condiments,
            ingredients: [ing("Organic Chickpeas"), ing("Organic Tahini"), ing("Organic Lemon Juice"), ing("Organic Garlic"), ing("Sea Salt")],
            claims: ["Organic", "Gluten Free"]
        ),

        // UNMATCHED products (contain common allergens: dairy, wheat, soy)
        MockInventoryProduct(
            id: "mock-011", name: "Chocolate Sandwich Cookies", brand: "Oreo", barcode: "0044000032210",
            category: .snacks,
            ingredients: [
                ing("Enriched Flour", sub: ["Wheat Flour", "Niacin", "Iron"]),
                ing("Sugar"), ing("Palm Oil"), ing("Cocoa"), ing("High Fructose Corn Syrup"),
                ing("Soy Lecithin"), ing("Salt"), ing("Artificial Flavor")
            ],
            claims: []
        ),
        MockInventoryProduct(
            id: "mock-012", name: "Mac & Cheese Classic", brand: "Annie's", barcode: "0001389201012",
            category: .bakery,
            ingredients: [
                ing("Organic Wheat Pasta", sub: ["Organic Wheat Flour"]),
                ing("Cheddar Cheese", sub: ["Milk", "Cheese Cultures", "Salt", "Enzymes"]),
                ing("Whey"), ing("Butter"), ing("Salt")
            ],
            claims: ["Organic"]
        ),
        MockInventoryProduct(
            id: "mock-013", name: "Greek Yogurt", brand: "Chobani", barcode: "0081890100013",
            category: .dairy,
            ingredients: [ing("Nonfat Milk"), ing("Live Active Cultures")],
            claims: ["High Protein", "Gluten Free"]
        ),
        MockInventoryProduct(
            id: "mock-014", name: "Wheat Bread", brand: "Dave's Killer Bread", barcode: "0001381400019",
            category: .bakery,
            ingredients: [
                ing("Organic Whole Wheat Flour"), ing("Water"), ing("Organic Cane Sugar"),
                ing("Organic Wheat Gluten"), ing("Organic Soybean Oil"), ing("Sea Salt"), ing("Yeast")
            ],
            claims: ["Organic", "Non-GMO"]
        ),
        MockInventoryProduct(
            id: "mock-015", name: "Cream Cheese", brand: "Philadelphia", barcode: "0002100006701",
            category: .dairy,
            ingredients: [ing("Pasteurized Milk"), ing("Cream"), ing("Cheese Culture"), ing("Salt"), ing("Carob Bean Gum")],
            claims: []
        ),

        // MIXED / varied
        MockInventoryProduct(
            id: "mock-016", name: "Honey Nut Cheerios", brand: "General Mills", barcode: "0001600012780",
            category: .cereals,
            ingredients: [
                ing("Whole Grain Oats"), ing("Sugar"), ing("Oat Bran"), ing("Corn Starch"),
                ing("Honey"), ing("Almond Flour"), ing("Salt"), ing("Vitamin E")
            ],
            claims: ["Whole Grain"]
        ),
        MockInventoryProduct(
            id: "mock-017", name: "Organic Ketchup", brand: "Annie's", barcode: "0001389202019",
            category: .condiments,
            ingredients: [ing("Organic Tomato Paste"), ing("Organic Distilled Vinegar"), ing("Water"), ing("Organic Sugar"), ing("Sea Salt"), ing("Organic Onion Powder")],
            claims: ["Organic", "No Artificial Flavors"]
        ),
        MockInventoryProduct(
            id: "mock-018", name: "Cauliflower Pizza Crust", brand: "Caulipower", barcode: "0085509800018",
            category: .frozen,
            ingredients: [
                ing("Cauliflower"), ing("Rice Flour"), ing("Water"), ing("Tapioca Starch"),
                ing("Potato Starch"), ing("Olive Oil"), ing("Sea Salt")
            ],
            claims: ["Gluten Free"]
        ),
        MockInventoryProduct(
            id: "mock-019", name: "Overnight Oats Cup", brand: "Mush", barcode: "0085511900011",
            category: .cereals,
            ingredients: [ing("Oats"), ing("Coconut Cream"), ing("Maple Syrup"), ing("Chia Seeds"), ing("Sea Salt")],
            claims: ["Plant-Based", "Gluten Free"]
        ),
        MockInventoryProduct(
            id: "mock-020", name: "Teriyaki Sauce", brand: "Kikkoman", barcode: "0004190001031",
            category: .condiments,
            ingredients: [ing("Soy Sauce", sub: ["Water", "Wheat", "Soybeans", "Salt"]), ing("Sugar"), ing("Vinegar"), ing("Garlic")],
            claims: []
        ),
    ]

    // MARK: - Mock Scan Generation

    static func generateMockScan(
        for product: MockInventoryProduct,
        foodNoteSections: [String]
    ) -> DTO.Scan {
        let analysis = generateAnalysis(for: product, foodNoteSections: foodNoteSections)

        let now = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime, .withFractionalSeconds])

        return DTO.Scan(
            id: product.id,
            scan_type: "barcode",
            barcode: product.barcode,
            state: "done",
            product_info: DTO.ScanProductInfo(
                name: product.name,
                brand: product.brand,
                ingredients: product.ingredients,
                images: nil,
                claims: product.claims
            ),
            product_info_source: "openfoodfacts",
            analysis_result: analysis,
            images: [],
            latest_guidance: nil,
            created_at: now,
            last_activity_at: now,
            is_favorited: false
        )
    }

    // MARK: - Analysis Generation

    private static func generateAnalysis(
        for product: MockInventoryProduct,
        foodNoteSections: [String]
    ) -> DTO.ScanAnalysisResult? {
        guard !foodNoteSections.isEmpty else {
            // No food notes → nullable analysis shape
            return DTO.ScanAnalysisResult(
                id: UUID().uuidString,
                overall_analysis: nil,
                overall_match: nil,
                ingredient_analysis: [],
                is_stale: false,
                vote: nil
            )
        }

        let productIngredientNames = product.ingredientNames
        var flaggedIngredients: [DTO.ScanIngredientAnalysis] = []

        for section in foodNoteSections {
            let sectionLower = section.lowercased()
            guard let keywords = allergenKeywordMap[sectionLower] else { continue }

            for keyword in keywords {
                for ingredientName in productIngredientNames {
                    if ingredientName.contains(keyword) {
                        let alreadyFlagged = flaggedIngredients.contains { $0.ingredient.lowercased() == ingredientName }
                        if !alreadyFlagged {
                            let isUncertain = ["soy lecithin", "natural flavors", "natural flavor"].contains(where: ingredientName.contains)
                            flaggedIngredients.append(DTO.ScanIngredientAnalysis(
                                ingredient: ingredientName.capitalized,
                                match: isUncertain ? "uncertain" : "unmatched",
                                reasoning: "Contains \(keyword) which conflicts with your \(section) preference.",
                                members_affected: ["Everyone"]
                            ))
                        }
                    }
                }
            }
        }

        let overallMatch: String
        if flaggedIngredients.isEmpty {
            overallMatch = "matched"
        } else if flaggedIngredients.allSatisfy({ $0.match == "uncertain" }) {
            overallMatch = "uncertain"
        } else {
            overallMatch = "unmatched"
        }

        let overallAnalysis: String
        switch overallMatch {
        case "matched":
            overallAnalysis = "This product appears to match your dietary preferences. No concerning ingredients were found."
        case "uncertain":
            overallAnalysis = "Some ingredients may need review based on your dietary preferences."
        default:
            overallAnalysis = "This product contains ingredients that conflict with your dietary preferences."
        }

        return DTO.ScanAnalysisResult(
            id: UUID().uuidString,
            overall_analysis: overallAnalysis,
            overall_match: overallMatch,
            ingredient_analysis: flaggedIngredients,
            is_stale: false,
            vote: nil
        )
    }

    // MARK: - Helpers

    private static func ing(_ name: String, sub: [String] = []) -> DTO.Ingredient {
        DTO.Ingredient(
            name: name,
            vegan: nil,
            vegetarian: nil,
            ingredients: sub.map { DTO.Ingredient(name: $0, vegan: nil, vegetarian: nil, ingredients: []) }
        )
    }
}

// MARK: - ScanAnalysisResult Convenience Init

extension DTO.ScanAnalysisResult {
    init(
        id: String?,
        overall_analysis: String?,
        overall_match: String?,
        ingredient_analysis: [DTO.ScanIngredientAnalysis],
        is_stale: Bool?,
        vote: DTO.Vote?
    ) {
        // Encode/decode round-trip to satisfy the Codable init
        // Use a simpler approach: build a JSON dictionary and decode
        let dict: [String: Any?] = [
            "id": id,
            "overall_analysis": overall_analysis,
            "overall_match": overall_match,
            "ingredient_analysis": ingredient_analysis.map { analysis -> [String: Any] in
                var d: [String: Any] = [
                    "ingredient": analysis.ingredient,
                    "match": analysis.match,
                    "reasoning": analysis.reasoning,
                    "members_affected": analysis.members_affected
                ]
                if let vote = analysis.vote {
                    d["vote"] = ["id": vote.id, "value": vote.value]
                }
                return d
            },
            "is_stale": is_stale,
            "vote": vote.map { ["id": $0.id, "value": $0.value] }
        ]

        let cleaned = dict.compactMapValues { $0 }
        let data = try! JSONSerialization.data(withJSONObject: cleaned)
        self = try! JSONDecoder().decode(DTO.ScanAnalysisResult.self, from: data)
    }
}
