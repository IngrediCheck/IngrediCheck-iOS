# Backend Call Sequence Diagrams

## Barcode Scan to Analysis

```mermaid
sequenceDiagram
    participant User
    participant Scanner as BarcodeScannerView
    participant Router as CheckTabState.routes
    participant VM as BarcodeAnalysisViewModel
    participant Service as WebService
    participant Inventory as GET /inventory
    participant Analyze as POST /analyze
    participant Favorites as /list_items & /list_items/{id}
    participant Feedback as POST /feedback

    User->>Scanner: Scan packaged barcode
    Scanner->>Router: push(.barcode)
    Router->>VM: init & analyze()
    VM->>Service: async let fetchProductDetailsFromBarcode()
    VM->>Service: async let fetchIngredientRecommendations()
    par Product lookup
        Service->>Inventory: GET inventory?clientActivityId&barcode
        Inventory-->>Service: 200 Product JSON
        Service-->>VM: DTO.Product
        VM->>Router: update UI with product
    and Ingredient analysis
        Service->>Analyze: POST analyze (preferences + barcode)
        Analyze-->>Service: 200 IngredientRecommendation[]
        Service-->>VM: recommendations
        VM->>Router: update UI with analysis
    end
    User->>VM: Toggle favorite
    VM->>Service: addToFavorites/removeFromFavorites
    Service->>Favorites: POST/DELETE list_items
    Favorites-->>Service: status 201/200
    User->>VM: Submit feedback
    VM->>Service: submitFeedback()
    Service->>Feedback: POST feedback
    Feedback-->>Service: status 201
```

## Label Photo Capture to Analysis

```mermaid
sequenceDiagram
    participant User
    participant Capture as ImageCaptureView
    participant CheckNav as CheckTabState.routes
    participant UploadTask as uploadImage Task
    participant SupaStorage as Supabase Storage bucket
    participant LabelVM as LabelAnalysisViewModel
    participant Service as WebService
    participant Extract as POST /extract
    participant Analyze as POST /analyze
    participant Feedback as POST /feedback

    loop For each snapshot
        User->>Capture: Tap shutter
        Capture->>UploadTask: startUploadTask(image)
        UploadTask->>SupaStorage: upload JPEG
        SupaStorage-->>UploadTask: stored hash
        Capture->>CheckNav: append(.productImages)
    end
    CheckNav->>LabelVM: init & analyze()
    LabelVM->>Service: extractProductDetailsFromLabelImages(productImages)
    Service->>Extract: POST extract (hash/OCR/barcode JSON)
    Extract-->>Service: 200 Product JSON
    Service-->>LabelVM: DTO.Product
    LabelVM->>Service: fetchIngredientRecommendations(preferences)
    Service->>Analyze: POST analyze (preferences only)
    Analyze-->>Service: 200 IngredientRecommendation[]
    Service-->>LabelVM: recommendations
    LabelVM->>CheckNav: update UI
    User->>LabelVM: Submit feedback
    LabelVM->>Service: submitFeedback()
    Service->>Feedback: POST feedback
    Feedback-->>Service: status 201
```

## Supporting Flows

- History & Favorites tabs refresh with `fetchHistory` (GET `/history[?searchText]`) and `getFavorites` (GET `/list_items/{defaultList}`); thumbnails fetch images via Supabase storage URLs when needed.
- Dietary preferences use `addOrEditDietaryPreference`, `deleteDietaryPreference`, `uploadGrandFatheredPreferences`, and `getDietaryPreferences`.
- Account deletion calls `deleteUserAccount`; clearing captured photos runs `deleteImages` to remove uploaded files.
