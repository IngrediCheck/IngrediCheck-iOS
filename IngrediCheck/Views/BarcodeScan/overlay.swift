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
                        .font(.system(size: 14, weight: .semibold))
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


struct tostmsg: View {
    var body: some View {
       
            
            
            
            ZStack {
                // Background rounded rectangle with material effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
                    .frame(width: 280, height: 36) // Adjust as needed
                
                
                // Icon + Text vertically stacked
                HStack(spacing: 8,) {
                    Image("ic_round-tips-and-updates")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                    
                    Text("Ensure good lighting and steady hands")
                        .font(.system(size : 12))
                        .foregroundColor(.white)
                }.padding(.horizontal)
            }

            // Icon + Text vertically stacked
            HStack(spacing: 8,) {
                Image("ic_round-tips-and-updates")
                    .font(.system(size: 20))
                    .foregroundColor(.white)

                Text("Ensure good lighting and steady hands")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }.padding(.horizontal)
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
                        .thinMaterial, in: .capsule
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
                Image( "left-arrow")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
            }
            .frame(width: 33, height: 33)
//            .padding(7.5)
            .background(
                .thinMaterial, in: .capsule
            )
           
        }
        .buttonStyle(.plain)
    }
}

struct BarcodeDataCard: View {
    let code: String

    @Environment(WebService.self) private var webService

    @State private var analysisResult: BarcodeScanAnalysisResult?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial.opacity(0.2))
                .frame(width: 300, height: 120)
            HStack {
                HStack(spacing: 47) {
                    // Left-side visual changes based on whether we have a barcode yet.
                    if code.isEmpty {
                        // Empty card: simple placeholder block, no barcode illustration.
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial.opacity(0.4))
                                .frame(width: 68, height: 92)
                        }
                    } else if let product = analysisResult?.product, let firstImage = product.images.first {
                        // After analysis: show the first product image if available.
                        ProductImageThumbnail(imageLocation: firstImage)
                            .frame(width: 71, height: 95)
                    } else {
                        // Barcode present but no image yet: show the animated/illustrated barcode stack.
                        ZStack {
                            Image("Barcodelinecorners")
                        }
                        .frame(width: 71, height: 95)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    if code.isEmpty {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.thinMaterial.opacity(0.4))
                                .frame(width: 185, height: 25)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 132, height: 20)
                            .padding(.bottom, 7)
                        RoundedRectangle(cornerRadius: 52)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 79, height: 24)
                    } else if isLoading || analysisResult == nil {
                        VStack(alignment: .leading) {
                            Text("Looking up this product…")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.white)
                                .padding(.bottom, 2)
                            Text("We’re checking our database for this Product")
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .font(.system(size: 10, weight: .semibold))
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
                                    .font(.system(size: 12))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .fontWeight(.semibold)
                            }
                            .frame(width: 130, height: 22)
                            .padding(8)
                            .background(
                                Capsule()
                                    .fill(.bar)
                            )
                        }
//                        .padding(.leading  )
                    } else if let result = analysisResult, let product = result.product {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name ?? "Product found")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if let brand = product.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            if let matchStatus = result.matchStatus {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(matchStatus.displayColor)
                                        .frame(width: 8, height: 8)
                                    Text(matchStatus.displayText)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(matchStatus.backgroundColor)
                                )
                            }
                        }
                    } else if let result = analysisResult, result.notFound {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("We couldn’t identify this product !")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.white)
                            Text("Help us identify it, add a few photos of the product.")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.9))
                                .lineLimit(2)
                        }
                    } else if let result = analysisResult, let error = result.errorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Something went wrong")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.white)
                            Text(error)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.9))
                                .lineLimit(2)
                        }
                    }
                }
                .frame(width: 185, height: 92)
                if code.isEmpty == false {
                    Image("iconamoon_arrow-up-2-duotone")
                }
            }
        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: code) {
            guard !code.isEmpty else { return }

            // If we already have a cached result for this barcode, reuse it and
            // avoid re-triggering a network call when swiping back to the card.
            if let cached = BarcodeScanAnalysisService.cachedResult(for: code) {
                analysisResult = cached
                isLoading = false
                return
            }

            isLoading = true
            let service = BarcodeScanAnalysisService(webService: webService, userPreferenceText: "None")
            let result = await service.analyze(barcode: code)
            analysisResult = result
            isLoading = false
        }
    }
}

private struct ProductImageThumbnail: View {
    let imageLocation: DTO.ImageLocationInfo

    @Environment(WebService.self) private var webService
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            // Background block, matching the placeholder size.
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial.opacity(0.4))
                .frame(width: 68, height: 92)

            if let image {
                // Explicitly size and clip the product image so it never
                // bleeds outside the visual frame.
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Image("Barcodelinecorners")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 68, height: 92)
            }
        }
        // Outer frame still matches the original 71x95 footprint used by the
        // barcode illustration state.
        .frame(width: 71, height: 95)
        .clipped()
        .task(id: imageLocationKey) {
            // Avoid refetching if already loaded
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
            return "Match"
        case .needsReview:
            return "Needs review"
        case .notMatch:
            return "Not a match"
        }
    }

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
}

#Preview {
    ZStack {
        BarcodeDataCard(code: "123456789012")
    }
    .background(Color.red.edgesIgnoringSafeArea(.all))
}
