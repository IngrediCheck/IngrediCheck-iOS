import SwiftUI

/// Skeleton/redacted card shown as the first card when camera opens or no active scans
struct SkeletonScanCard: View {
    var scanType: String = "barcode"  // "barcode" or "photo"
    
    var body: some View {
        HStack(spacing: 14) {
            // Left-side: skeleton image placeholder
            ZStack {                
                // Placeholder icon based on scan type
                let placeholderImage = scanType == "photo" ? "PhotoScanEmptyState" : "Barcodelinecorners"
                Image(placeholderImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 88)
                    .clipped()
            }
            .frame(width: 68, height: 92)
            .padding(.leading, 14)
            .layoutPriority(1)
            
            // Right-side: skeleton text placeholders
            VStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.bar)
                    .opacity(0.4)
                    .frame(width: 185, height: 25)
                    .padding(.bottom, 4)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.bar)
                    .opacity(0.4)
                    .frame(width: 132, height: 20)
                    .padding(.bottom, 6)
                RoundedRectangle(cornerRadius: 52)
                    .fill(.bar)
                    .opacity(0.4)
                    .frame(width: 79, height: 24)
            }
            .frame(maxWidth: .infinity,
                   minHeight: 92,
                   maxHeight: 92,
                   alignment: .leading
            )
            
            Spacer()
                .frame(width: 14)
        }
        .frame(width: 300, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.bar)
                .opacity(0.4)
        )
        .clipped()
    }
}

