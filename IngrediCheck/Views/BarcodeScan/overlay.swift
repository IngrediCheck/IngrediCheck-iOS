    import SwiftUI
    import UIKit

    struct ScannerOverlay: View {
        @State private var scanY: CGFloat = 0
        var onRectChange: ((CGRect, CGSize) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let rect = centerRect(in: geo)
            ZStack {
                ZStack{
                    // Dark overlay with a rounded-rect cutout
                    CutoutOverlay(rect: rect)
                    // Frame image
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: rect.width - 4, height: 3)
                        .shadow(
                            color: Color.yellow.opacity(1),
                                radius: 12,          // no blur — keeps shadow sharp
                                x: 0,
                                y: 8               // positive = bottom only
                            )
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .position(x: rect.midX , y: rect.midY + scanY )
                        .onAppear {
                            scanY =  ( -rect.height / 2 ) + 6
                            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                scanY = ( rect.height / 2 ) - 6
                            }
                        }
                    Image("Scannerborderframe")
                        .resizable()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    // Scanning line clipped inside the rounded rect (no glow leak)
                  
                    
                }
                    
                
                VStack{
                    // Hint text below
                    Text("Align the barcode within the frame to scan")
                        .frame(width: 220, height: 42)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .font(ManropeFont.medium.size(14))
                        .foregroundColor(Color.grayScale10)
                        .position(x: rect.midX, y: rect.maxY + 28)
                }.padding(.top ,24)
            }
            .onAppear { onRectChange?(rect, geo.size) }
            .onChange(of: geo.size) { newSize in onRectChange?(rect, newSize) }
        }
        .ignoresSafeArea()
    }


        func centerRect(in geo: GeometryProxy) -> CGRect {
            let width: CGFloat = 286
            let height: CGFloat = 121
            return CGRect(
                x: (geo.size.width - width) / 2,
                y: 209,
                width: width,
                height: height
            )
        }
    }

    struct CutoutOverlay: View {
        var rect: CGRect

        var body: some View {
            Color.black.opacity(0.5)
                .mask(
                    CutoutShape(rect: rect)
                        .fill(style: FillStyle(eoFill: true))
                )
                .ignoresSafeArea()
        }
    }

    struct CutoutShape: Shape {
        let rect: CGRect
        let cornerRadius: CGFloat = 12   // <<--- change this value

        func path(in bounds: CGRect) -> Path {
            var path = Path()

            // Full dark overlay
            path.addRect(bounds)

            // Rounded transparent hole
            let rounded = UIBezierPath(
                roundedRect: rect,
                cornerRadius: cornerRadius
            )
            path.addPath(Path(rounded.cgPath))

            return path
        }
    }






    #Preview {
        
    }


enum ToastScanState {
    case scanning               // user is scanning / live camera
    case extractionSuccess      // barcode extracted successfully
    case notIdentified          // product could not be identified
    case analyzing              // product detected, reading ingredients
    case match                  // product matches preferences
    case notMatch               // product does not match preferences
    case uncertain              // some ingredients are unclear
    case retry                  // retry / retake photo
    case photoGuide             // camera/photo mode guidance
}

struct tostmsg: View {
    let state: ToastScanState
    
    @State private var shimmerPhase: CGFloat = -1
    // Wider and slower shimmer so it's very visible to the eye.
    private let shimmerGradientWidth: CGFloat = 110
    private let animationDuration: Double = 1.8
    
    private var iconName: String {
        switch state {
        case .scanning:
            return "ic_round-tips-and-updates"
        default:
            // For all non-scanning states we use the analysis icon
            return "analysisicon"
        }
    }
    
    private var message: String {
        switch state {
        case .scanning:
            return "Ensure good lighting and steady hands"
        case .extractionSuccess:
            return "Scanning successful. Fetching data…"
        case .notIdentified:
            return "Scan again or add photos for better results."
        case .analyzing:
            return "Product detected, reading ingredients."
        case .match:
            return "Good news! This product matches your preferences."
        case .notMatch:
            return "This product contains ingredients you avoid."
        case .uncertain:
            return "Some ingredients are unclear."
        case .retry:
            return "Retake the photo for a clearer scan."
        case .photoGuide:
            return "Capture clear photos of the product and ingredients."
        }
    }
    
    var body: some View {
        labelContent
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
                    .opacity(0.4)
            )
            .overlay(
                // Shimmer effect - moves left to right across the dynamic content width
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.9),
                            Color.white.opacity(1.0),
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerGradientWidth)
                    // Move the shimmer a bit farther so it fully covers
                    // the last characters instead of stopping short.
                    .offset(x: shimmerPhase * (width + shimmerGradientWidth))
                    // Screen blend mode makes the highlight much more visible
                    // over the dimmed base text/icon.
                    .blendMode(.screen)
                }
                .mask(
                    labelContent
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                )
            )
            .onAppear {
                startShimmer()
            }
            .onChange(of: state) { _ in
                startShimmer()
            }
            .animation(.easeInOut(duration: 0.2), value: state)
    }
    
    @ViewBuilder
    private var labelContent: some View {
        HStack(spacing: 8) {
            Image(iconName)
                .resizable()
                .renderingMode(.template)
                .frame(width: 19, height: 19)
                .foregroundColor(.white.opacity(0.6))
            
            Text(message)
                .font(ManropeFont.medium.size(12))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private func startShimmer() {
        shimmerPhase = -1
        withAnimation(
            Animation
                .linear(duration: animationDuration)
                .delay(0.1)
                .repeatForever(autoreverses: false)
        ) {
            shimmerPhase = 1
        }
    }
}

#Preview {
    ZStack{
        VStack(spacing: 12) {
            tostmsg(state: .scanning)
            tostmsg(state: .extractionSuccess)
            tostmsg(state: .match)
            tostmsg(state: .notMatch)
            tostmsg(state: .uncertain)
            tostmsg(state: .retry)
        }
    }
}

struct Flashcapsul: View {
    @State private var isFlashon = false
    /// When `true`, show the system torch icon; when `false`, show the custom flash asset.
    var isScannerMode: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if isScannerMode {
                // Scanner mode: show torch icon only
                ZStack{
                    Image(systemName: isFlashon ? "flashlight.on.fill" : "flashlight.off.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    
                        .foregroundColor(.white)
                }.frame(width: 33, height: 33)
                    .background(
                        .thinMaterial.opacity(0.4), in: .capsule
                    )
            } else {
                // Photo mode: show custom flash asset + label
                ZStack {
                    Circle()
                        .fill(.thinMaterial.opacity(0.4))
                        .frame(width: 48, height: 48)
                    Image(isFlashon ? "flashon" : "flashoff")
                        .resizable()
                        .frame(width: 28, height: 24)
                        .foregroundColor(.white)
                }
            
            }
        }
        
//        .padding(7.5)
        
        
        .onTapGesture {
            withAnimation(.easeInOut) {
                FlashManager.shared.toggleFlash { on in
                    self.isFlashon = on
                }
            }
        }
        .onAppear {
            isFlashon = FlashManager.shared.isFlashOn()
        }
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Image( "angle-left-arrow")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
            }
            .frame(width: 33, height: 33)
//            .padding(7.5)
            .background(
                .thinMaterial.opacity(0.4), in: .capsule
            )
           
        }
        .buttonStyle(.plain)
    }
}

struct BarcodeDataCard: View {
    let code: String
    var onRetryShown: (() -> Void)? = nil
    var onRetryHidden: (() -> Void)? = nil
    var onResultUpdated: (() -> Void)? = nil

    @Environment(WebService.self) private var webService

    @State private var analysisResult: BarcodeScanAnalysisResult?
    @State private var isLoading = false
    @State private var product: DTO.Product?
    @State private var ingredientRecommendations: [DTO.IngredientRecommendation]?
    @State private var matchStatus: DTO.ProductRecommendation?
    @State private var notFoundState = false
    @State private var errorState: String?
    @State private var hasCompleted = false
    @State private var isAnalyzing = false

    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial)
                .opacity(0.4)
                .frame(width: 300, height: 120)
            HStack(alignment: .center, spacing: 10) {
                // Left-side visual changes based on whether we have a barcode yet.
                if code.isEmpty {
                    // Empty card: simple placeholder block, no barcode illustration.
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                            .opacity(0.4)
                            .frame(width: 68, height: 92)
                    }
                    
                } else if let product = product, let firstImage = product.images.first {
                    // After product is known: show first product image with analyzing overlay when needed.
                    ProductImageThumbnail(imageLocation: firstImage, isAnalyzing: isAnalyzing)
                        .frame(width: 68, height: 92)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white, lineWidth: 0.5)
                        )
                } else if product != nil {
                    // Product details were found but there is no image in the API response.
                    // Show the default "image not found" placeholder.
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                            .opacity(0.4)
                            .frame(width: 68, height: 92)
                        Image("imagenotfound1")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 39, height: 34)
                    }
                } else {
                    // Barcode present but product is not yet known: show the barcode placeholder stack.
                    ZStack {
                        Image("Barcodelinecorners")
                    }
                    .frame(width: 68, height: 92)
                }
                VStack(alignment: .leading) {
                    if code.isEmpty {
                        
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.thinMaterial)
                                .opacity(0.4)
                                .frame(width: 185, height: 25)
                                .padding(.bottom, 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.thinMaterial)
                            .opacity(0.4)
                            .frame(width: 132, height: 20)
                            .padding(.bottom, 14)
                        RoundedRectangle(cornerRadius: 52)
                            .fill(.thinMaterial)
                            .opacity(0.4)
                            .frame(width: 79, height: 24)
                        
                    } else if isLoading && product == nil {
                        VStack(alignment: .leading) {
                            Text("Looking up this product…")
                                .font(ManropeFont.bold.size(12))
                                .foregroundColor(Color.white)
                                .padding(.bottom, 2)
                            Text("We're checking our database for this Product")
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .font(ManropeFont.semiBold.size(10))
                                .foregroundColor(Color.white)
                            Spacer(minLength: 8)
                            HStack(spacing: 8) {
                                ProgressView() // default spinner
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(
                                        LinearGradient(
                                            colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    ) // 👈 visible but still "material" looking
                                    .scaleEffect(1) // make it a bit bigger
                                    .frame(width: 16, height: 16)
                                Text("Fetching details")
                                    .font(NunitoFont.semiBold.size(12))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            .frame(width: 130, height: 22)
                            .padding(8)
                            .background(
                                Capsule()
                                    .fill(.bar)
                            )
                        }
                    } else if let product = product {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.brand ?? "Brand not  found")
                                .font(ManropeFont.regular.size(12))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if let product = product.name, !product.isEmpty {
                                Text(product ?? "Product not Found")
                                    .font(NunitoFont.semiBold.size(16))
                                    .foregroundColor(Color.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 8)
                            if ingredientRecommendations == nil && errorState == nil && notFoundState == false {
                                HStack(spacing: 6) {
                                    Image("analysisicon")
                                        .frame(width: 18, height: 18)
                                    Text("Analyzing")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#3DA8F5"), Color(hex: "#3DACFB")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            } else if let matchStatus = matchStatus {
                                HStack(spacing: 4) {
                                    Image(matchStatus.iconAssetName)
                                        .frame(width: 18, height: 18)
                                    Text(matchStatus.displayText)
                                        .font(NunitoFont.medium.size(12))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: matchStatus.gradientColors,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            } else if errorState != nil && product != nil {
                                // Analysis failed but product was found - show Retry button
                                Button(action: {
                                    retryAnalysis()
                                }) {
                                    HStack(spacing: 4) {
                                        Image("stasharrow-retry")
                                            .frame(width: 18, height: 18)
                                        Text("Retry")
                                            .font(NunitoFont.medium.size(12))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "#B5B5B5"), Color(hex: "#D3D3D3")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    // Show callout bubble when retry button appears
                                    onRetryShown?()
                                }
                            }
                        }
                    } else if notFoundState {
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text("We couldn't identify this product ")
                                .font(ManropeFont.bold.size(11))
                                .foregroundColor(Color.white)
                            Text("Help us identify it, add a few photos of the product.")
                                .font(ManropeFont.semiBold.size(10))
                                .foregroundColor(Color.white.opacity(0.9))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                    } else if let error = errorState, product == nil {
                        // Only show error text if we don't have a product (no retry option)
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text("Something went wrong")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.white)
                            Text(error)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.9))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                    }
                }
                // Ensure content (brand/product text + status capsule) has
                // comfortable vertical insets inside the card: at least 12pt
                // above the brand name and below the last capsule.
                .padding(.vertical, 12)
                .frame(width: 185, height: 92, alignment: .topLeading)
                .onChange(of: errorState) { newErrorState in
                    // Hide callout when error is cleared (analysis succeeded or retry clicked)
                    if newErrorState == nil && product != nil {
                        onRetryHidden?()
                    }
                }
                .onChange(of: matchStatus) { newMatchStatus in
                    // Hide callout when analysis completes successfully
                    if newMatchStatus != nil {
                        onRetryHidden?()
                    }
                }
                if code.isEmpty == false {
                    VStack {
                        Spacer()
                        Image("iconamoon_arrow-up-2-duotone")
                        Spacer()
                    }
                    .frame(height: 120)
                }
            }
            .frame(height: 120)
            .padding(.leading, 14)
        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: code) {
            guard !code.isEmpty else { return }

            // If we already analyzed this barcode in this app session, reuse
            // the cached result immediately so we don't block the UI.
            if let cached = BarcodeScanAnalysisService.cachedResult(for: code) {
                analysisResult = cached
                product = cached.product
                ingredientRecommendations = cached.ingredientRecommendations
                matchStatus = cached.matchStatus
                notFoundState = cached.notFound
                errorState = cached.errorMessage
                isLoading = false
                isAnalyzing = false
                onResultUpdated?()
                return
            }

            // Reset local UI state before kicking off background analysis.
            isLoading = true
            isAnalyzing = false
            product = nil
            ingredientRecommendations = nil
            matchStatus = nil
            notFoundState = false
            errorState = nil

            let codeToAnalyze = code
            let clientActivityId = UUID().uuidString
            let preferenceText = DietaryPreferenceConfig.defaultText
            let service = webService

            // Run the streaming analysis on a detached background task so
            // camera preview + scan-line animation stay responsive.
            Task.detached {
                do {
                    try await service.streamUnifiedAnalysis(
                        input: .barcode(codeToAnalyze),
                        clientActivityId: clientActivityId,
                        userPreferenceText: preferenceText,
                        onProduct: { value in
                            // onProduct/onAnalysis/onError are already
                            // dispatched to the MainActor inside
                            // WebService.streamUnifiedAnalysis.
                            product = value
                            isAnalyzing = true
                            
                            // Cache an intermediate result so UI like the toast
                            // can reflect that a product was detected and we're
                            // now reading ingredients.
                            let intermediate = BarcodeScanAnalysisResult(
                                product: product,
                                ingredientRecommendations: nil,
                                matchStatus: nil,
                                notFound: false,
                                errorMessage: nil,
                                barcode: codeToAnalyze,
                                clientActivityId: clientActivityId
                            )
                            Task { @MainActor in
                                BarcodeScanAnalysisService.storeResult(intermediate)
                                onResultUpdated?()
                            }
                        },
                        onAnalysis: { recs in
                            ingredientRecommendations = recs
                            if let p = product {
                                matchStatus = p.calculateMatch(ingredientRecommendations: recs)
                            }
                            let result = BarcodeScanAnalysisResult(
                                product: product,
                                ingredientRecommendations: ingredientRecommendations,
                                matchStatus: matchStatus,
                                notFound: false,
                                errorMessage: nil,
                                barcode: codeToAnalyze,
                                clientActivityId: clientActivityId
                            )
                            // Cache update must happen on the main actor because
                            // BarcodeScanAnalysisService is @MainActor.
                            Task { @MainActor in
                                BarcodeScanAnalysisService.storeResult(result)
                                isAnalyzing = false
                                isLoading = false
                                onResultUpdated?()
                            }
                        },
                        onError: { streamError in
                            if streamError.statusCode == 404 {
                                // Cache a not-found result so revisiting this
                                // barcode shows the not-found message instead
                                // of re-fetching every time.
                                let result = BarcodeScanAnalysisResult(
                                    product: nil,
                                    ingredientRecommendations: nil,
                                    matchStatus: nil,
                                    notFound: true,
                                    errorMessage: nil,
                                    barcode: codeToAnalyze,
                                    clientActivityId: clientActivityId
                                )
                                Task { @MainActor in
                                    BarcodeScanAnalysisService.storeResult(result)
                                    notFoundState = true
                                    isAnalyzing = false
                                    isLoading = false
                                    onResultUpdated?()
                                }
                            } else {
                                // For non-404 errors, cache an error result so
                                // the toast and other UI can show a retry hint.
                                let result = BarcodeScanAnalysisResult(
                                    product: product,
                                    ingredientRecommendations: ingredientRecommendations,
                                    matchStatus: matchStatus,
                                    notFound: false,
                                    errorMessage: streamError.message,
                                    barcode: codeToAnalyze,
                                    clientActivityId: clientActivityId
                                )
                                Task { @MainActor in
                                    BarcodeScanAnalysisService.storeResult(result)
                                    errorState = streamError.message
                                    isAnalyzing = false
                                    isLoading = false
                                    onResultUpdated?()
                                }
                            }
                        }
                    )
                } catch NetworkError.notFound(_) {
                    let result = BarcodeScanAnalysisResult(
                        product: nil,
                        ingredientRecommendations: nil,
                        matchStatus: nil,
                        notFound: true,
                        errorMessage: nil,
                        barcode: codeToAnalyze,
                        clientActivityId: clientActivityId
                    )
                    await MainActor.run {
                        BarcodeScanAnalysisService.storeResult(result)
                        notFoundState = true
                        isAnalyzing = false
                        isLoading = false
                        onResultUpdated?()
                    }
                } catch {
                    // Generic failure: cache an error result so the toast can
                    // show a retry message for this barcode.
                    let result = BarcodeScanAnalysisResult(
                        product: product,
                        ingredientRecommendations: ingredientRecommendations,
                        matchStatus: matchStatus,
                        notFound: false,
                        errorMessage: error.localizedDescription,
                        barcode: codeToAnalyze,
                        clientActivityId: clientActivityId
                    )
                    await MainActor.run {
                        BarcodeScanAnalysisService.storeResult(result)
                        errorState = error.localizedDescription
                        isAnalyzing = false
                        isLoading = false
                        onResultUpdated?()
                    }
                }
            }
        }
    }
    
    /// Retry the analysis when it fails
    private func retryAnalysis() {
        guard !code.isEmpty else { return }
        
        // Clear error state and reset analysis flags
        errorState = nil
        ingredientRecommendations = nil
        matchStatus = nil
        isAnalyzing = false
        isLoading = true
        
        // Clear cached result so we force a fresh analysis
        BarcodeScanAnalysisService.clearResult(for: code)
        
        let codeToAnalyze = code
        let clientActivityId = UUID().uuidString
        let preferenceText = DietaryPreferenceConfig.defaultText
        let service = webService
        
        // Re-run the streaming analysis
        Task.detached {
            do {
                try await service.streamUnifiedAnalysis(
                    input: .barcode(codeToAnalyze),
                    clientActivityId: clientActivityId,
                    userPreferenceText: preferenceText,
                    onProduct: { value in
                        product = value
                        isAnalyzing = true
                    },
                    onAnalysis: { recs in
                        ingredientRecommendations = recs
                        if let p = product {
                            matchStatus = p.calculateMatch(ingredientRecommendations: recs)
                        }
                        let result = BarcodeScanAnalysisResult(
                            product: product,
                            ingredientRecommendations: ingredientRecommendations,
                            matchStatus: matchStatus,
                            notFound: false,
                            errorMessage: nil,
                            barcode: codeToAnalyze,
                            clientActivityId: clientActivityId
                        )
                        Task { @MainActor in
                            BarcodeScanAnalysisService.storeResult(result)
                            isAnalyzing = false
                            isLoading = false
                            onResultUpdated?()
                        }
                    },
                    onError: { streamError in
                        if streamError.statusCode == 404 {
                            let result = BarcodeScanAnalysisResult(
                                product: nil,
                                ingredientRecommendations: nil,
                                matchStatus: nil,
                                notFound: true,
                                errorMessage: nil,
                                barcode: codeToAnalyze,
                                clientActivityId: clientActivityId
                            )
                            Task { @MainActor in
                                BarcodeScanAnalysisService.storeResult(result)
                                notFoundState = true
                                isAnalyzing = false
                                isLoading = false
                                onResultUpdated?()
                            }
                        } else {
                            let result = BarcodeScanAnalysisResult(
                                product: product,
                                ingredientRecommendations: ingredientRecommendations,
                                matchStatus: matchStatus,
                                notFound: false,
                                errorMessage: streamError.message,
                                barcode: codeToAnalyze,
                                clientActivityId: clientActivityId
                            )
                            Task { @MainActor in
                                BarcodeScanAnalysisService.storeResult(result)
                                errorState = streamError.message
                                isAnalyzing = false
                                isLoading = false
                                onResultUpdated?()
                            }
                        }
                    }
                )
            } catch NetworkError.notFound(_) {
                let result = BarcodeScanAnalysisResult(
                    product: nil,
                    ingredientRecommendations: nil,
                    matchStatus: nil,
                    notFound: true,
                    errorMessage: nil,
                    barcode: codeToAnalyze,
                    clientActivityId: clientActivityId
                )
                await MainActor.run {
                    BarcodeScanAnalysisService.storeResult(result)
                    notFoundState = true
                    isAnalyzing = false
                    isLoading = false
                    onResultUpdated?()
                }
            } catch {
                let result = BarcodeScanAnalysisResult(
                    product: product,
                    ingredientRecommendations: ingredientRecommendations,
                    matchStatus: matchStatus,
                    notFound: false,
                    errorMessage: error.localizedDescription,
                    barcode: codeToAnalyze,
                    clientActivityId: clientActivityId
                )
                await MainActor.run {
                    BarcodeScanAnalysisService.storeResult(result)
                    errorState = error.localizedDescription
                    isAnalyzing = false
                    isLoading = false
                    onResultUpdated?()
                }
            }
        }
    }
}

private struct ProductImageThumbnail: View {
    let imageLocation: DTO.ImageLocationInfo
    let isAnalyzing: Bool

    @Environment(WebService.self) private var webService
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial.opacity(0.4))
                .frame(width: 68, height: 92)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // When the image cannot be loaded from the server, fall back to
                // the default "imagenotfound1" asset.
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.thinMaterial.opacity(0.4))
                        .frame(width: 68, height: 92)
                    Image("imagenotfound1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 39, height: 34)
                }
            }

            if isAnalyzing {
                Color.black.opacity(0.25)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(width: 68, height: 92)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(.white)
            }
        }
        .clipped()
        .task(id: imageLocationKey) {
            guard image == nil else { return }
            if let uiImage = try? await webService.fetchImage(imageLocation: imageLocation, imageSize: .small) {
                image = uiImage
            }
        }
    }

    private var imageLocationKey: String {
        switch imageLocation {
        case .url(let url):
            return url.absoluteString
        case .imageFileHash(let hash):
            return hash
        }
    }
}

private extension DTO.ProductRecommendation {
    var displayText: String {
        switch self {
        case .match:
            return "Matched"
        case .needsReview:
            return "Uncertain"
        case .notMatch:
            return "UnMatch"
        }
    }

    // Keep legacy colors in case other parts of the app still reference them.
    var displayColor: Color {
        switch self {
        case .match:
            return Color.success100
        case .needsReview:
            return Color.warning100
        case .notMatch:
            return Color.fail100
        }
    }

    var backgroundColor: Color {
        switch self {
        case .match:
            return Color.success25
        case .needsReview:
            return Color.warning25
        case .notMatch:
            return Color.fail25
        }
    }

    // New gradient colors for the status pill.
    var gradientColors: [Color] {
        switch self {
        case .match:
            return [Color(hex: "#91B640"), Color(hex: "#89BF12")]
        case .needsReview:
            return [Color(hex: "#FAB222"), Color(hex: "#E8AF3E")]
        case .notMatch:
            return [Color(hex: "#FF594E"), Color(hex: "#FF3225")]
        }
    }

    // Icons per state.
  

    // Asset icons per state (provided in Assets.xcassets)
    var iconAssetName: String {
        switch self {
        case .match:
            return "charm_circle-tick"
        case .needsReview:
            return "famicons_warning-outline"
        case .notMatch:
            return "maki_cross"
        }
    }
}

#Preview {
    ZStack {
        BarcodeDataCard(code: "123456789012")
    }
    .background(Color.red.edgesIgnoringSafeArea(.all))
}
