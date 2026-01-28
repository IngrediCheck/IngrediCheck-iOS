import SwiftUI
import UIKit

/// Overlay view that displays the barcode scanning frame with animated scanning line and hint text
struct BarcodeScannerOverlay: View {
    @State private var scanY: CGFloat = 0
    var onRectChange: ((CGRect, CGSize) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let rect = centerRect(in: geo)
            ZStack {
                ZStack {
                    // Dark overlay with a rounded-rect cutout
                    CutoutOverlay(rect: rect)
                    
                    // Animated yellow scanning line (clipped to scanner frame)
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: rect.width - 4, height: 3)
                        .shadow(
                            color: Color.yellow.opacity(1),
                            radius: 12,
                            x: 0,
                            y: 8
                        )
                        .offset(y: scanY)
                        .frame(width: rect.width, height: rect.height)
                        .clipped()
                        .position(x: rect.midX, y: rect.midY)
                        .onAppear {
                            scanY = (-rect.height / 2) + 6
                            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                scanY = (rect.height / 2) - 6
                            }
                        }
                    
                    // Scanner border frame
                    Image("Scannerborderframe")
                        .resizable()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
                
                VStack {
                    // Hint text below scanner frame
                    Text("Align the barcode within the frame to scan")
                        .frame(width: 220, height: 42)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .font(ManropeFont.medium.size(14))
                        .foregroundColor(Color.grayScale10)
                        .position(x: rect.midX, y: rect.maxY + 28)
                }.padding(.top, 24)
            }
            .onAppear { onRectChange?(rect, geo.size) }
            .onChange(of: geo.size) { newSize in onRectChange?(rect, newSize) }
        }
        .ignoresSafeArea()
    }

    /// Calculate the center rect for the scanner frame
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
