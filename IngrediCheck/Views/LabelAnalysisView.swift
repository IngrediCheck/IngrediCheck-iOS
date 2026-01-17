
import SwiftUI
import SimpleToast
import PostHog

@MainActor @Observable class LabelAnalysisViewModel {
    
    let scanId: String
    let webService: WebService
    let dietaryPreferences: DietaryPreferences
    let userPreferences: UserPreferences

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var pollingTask: Task<Void, Never>?

    init(_ scanId: String, _ webService: WebService, _ dietaryPreferences: DietaryPreferences, _ userPreferences: UserPreferences) {
        self.scanId = scanId
        self.webService = webService
        self.dietaryPreferences = dietaryPreferences
        self.userPreferences = userPreferences
        impactFeedback.prepare()
    }
    
    @MainActor var scan: DTO.Scan? = nil
    @MainActor var product: DTO.Product? = nil
    @MainActor var error: Error? = nil
    @MainActor var ingredientRecommendations: [DTO.IngredientRecommendation]? = nil
    @MainActor var feedbackData = FeedbackData()
    @MainActor var latestGuidance: String? = nil
    let clientActivityId = UUID().uuidString

    func impactOccurred() {
        impactFeedback.impactOccurred()
    }

    func analyze() async {
        let requestId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970
        self.error = nil

        Log.debug("PHOTO_SCAN", "🔵 Starting photo scan analysis - scan_id: \(scanId), request_id: \(requestId)")
        Log.debug("PHOTO_SCAN", "⏳ Polling: YES (polling GET /scan/{scan_id} every 2 seconds)")

        PostHogSDK.shared.capture("Photo Scan Analysis Started", properties: [
            "request_id": requestId,
            "client_activity_id": clientActivityId,
            "scan_id": scanId
        ])

        // Poll for scan status
        pollingTask = Task {
            var isComplete = false
            var pollCount = 0
            
            while !isComplete && !Task.isCancelled {
                pollCount += 1
                do {
                    Log.debug("PHOTO_SCAN", "🔄 Poll #\(pollCount) - Getting scan status for scan_id: \(scanId)")
                    let currentScan = try await webService.getScan(scanId: scanId)
                    
                    await MainActor.run {
                        self.scan = currentScan
                        self.latestGuidance = currentScan.latest_guidance
                        
                        // Update product from scan
                        let productInfo = currentScan.product_info
                        let imageLocations: [DTO.ImageLocationInfo] = productInfo.images?.compactMap { scanImageInfo in
                            guard let urlString = scanImageInfo.url,
                                  let url = URL(string: urlString) else {
                                return nil
                            }
                            return .url(url)
                        } ?? []
                        
                        self.product = DTO.Product(
                            barcode: currentScan.barcode,
                            brand: productInfo.brand,
                            name: productInfo.name,
                            ingredients: productInfo.ingredients,
                            images: imageLocations,
                            claims: nil
                        )
                        
                        // Update recommendations when analysis is complete
                        if currentScan.state == "done",
                           let analysisResult = currentScan.analysis_result {
                            let totalLatency = (Date().timeIntervalSince1970 - startTime) * 1000
                            Log.debug("PHOTO_SCAN", "✅ Analysis complete - scan_id: \(self.scanId), poll_count: \(pollCount), total_latency: \(Int(totalLatency))ms")
                            Log.debug("PHOTO_SCAN", "🎯 Stopping polls - state: done")
                            
                            withAnimation {
                                self.ingredientRecommendations = analysisResult.toIngredientRecommendations()
                            }
                            self.impactOccurred()
                            self.userPreferences.incrementScanCount()
                            
                            PostHogSDK.shared.capture("Photo Scan Analysis Completed", properties: [
                                "request_id": requestId,
                                "client_activity_id": self.clientActivityId,
                                "scan_id": self.scanId,
                                "recommendations_count": self.ingredientRecommendations?.count ?? 0,
                                "total_latency_ms": totalLatency
                            ])
                            
                            isComplete = true
                        } else {
                            Log.debug("PHOTO_SCAN", "⏳ Still processing - scan_id: \(self.scanId), state: \(currentScan.state), continuing to poll...")
                        }
                    }
                    
                    if !isComplete {
                        Log.debug("PHOTO_SCAN", "⏸️ Waiting 2 seconds before next poll...")
                        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
                    }
                } catch {
                    await MainActor.run {
                        if !Task.isCancelled {
                            let totalLatency = (Date().timeIntervalSince1970 - startTime) * 1000
                            Log.debug("PHOTO_SCAN", "❌ Poll error - scan_id: \(self.scanId), poll_count: \(pollCount), error: \(error.localizedDescription)")
                            self.error = error
                            
                            PostHogSDK.shared.capture("Photo Scan Polling Failed", properties: [
                                "request_id": requestId,
                                "client_activity_id": self.clientActivityId,
                                "scan_id": self.scanId,
                                "error": error.localizedDescription,
                                "total_latency_ms": totalLatency
                            ])
                        }
                        isComplete = true
                    }
                }
            }
        }
        
        await pollingTask?.value
        impactOccurred()
    }
    
    func cancel() {
        pollingTask?.cancel()
    }

    func submitFeedback() {
        Task {
            try? await webService.submitFeedback(clientActivityId: clientActivityId, feedbackData: feedbackData)
        }
    }
}

struct LabelAnalysisView: View {
    
    let scanId: String

    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(DietaryPreferences.self) var dietaryPreferences
    @Environment(AppState.self) var appState
    @Environment(CheckTabState.self) var checkTabState

    @State private var viewModel: LabelAnalysisViewModel?
    @State private var showToast: Bool = false

    var body: some View {
        Group {
            if let viewModel {
                @Bindable var viewModelBindable = viewModel
                if let error = viewModel.error {
                    Text("Error: \(error.localizedDescription)")
                } else if let product = viewModel.product {
                    ScrollView {
                        VStack(spacing: 15) {

                            if let name = product.name {
                                Text(name)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal)
                            }

                            ProductImagesView(images: product.images) {
                                Task { @MainActor in
                                    _ = checkTabState.routes.popLast()
                                }
                            }
                            
                            // Display latest guidance if available
                            if let guidance = viewModel.latestGuidance, !guidance.isEmpty {
                                Text(guidance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }

                            if let brand = product.brand {
                                Text(brand)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal)
                            }
                            
                            AnalysisResultView(product: product, ingredientRecommendations: viewModel.ingredientRecommendations)
                            
                            HStack {
                                Text("Ingredients").font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            IngredientsText(ingredients: product.ingredients, ingredientRecommendations: viewModel.ingredientRecommendations)
                                .padding(.horizontal)
                        }
                    }
                    .simpleToast(isPresented: $showToast, options: SimpleToastOptions(hideAfter: 3)) {
                        FeedbackSuccessToastView()
                    }
                    .scrollIndicators(.hidden)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if viewModel.ingredientRecommendations != nil {
                                StarButton(clientActivityId: viewModel.clientActivityId, favorited: false)
                                Button(action: {
                                    checkTabState.feedbackConfig = FeedbackConfig(
                                        feedbackData: $viewModelBindable.feedbackData,
                                        feedbackCaptureOptions: .feedbackOnly,
                                        onSubmit: {
                                            showToast.toggle()
                                            viewModel.submitFeedback()
                                        }
                                    )
                                }, label: {
                                    Image(systemName: "flag")
                                        .font(.subheadline)
                                })
                            }
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Analyzing Image...")
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                VStack {
                    Spacer()
                    if let guidance = viewModel?.latestGuidance, !guidance.isEmpty {
                        Text(guidance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        Text("Analyzing Image...")
                    }
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .task {
                    let newViewModel = LabelAnalysisViewModel(scanId, webService, dietaryPreferences, userPreferences)
                    DispatchQueue.main.async { self.viewModel = newViewModel }
                    Task { await newViewModel.analyze() }
                }
                .onDisappear {
                    viewModel?.cancel()
                }
            }
        }
    }
}
