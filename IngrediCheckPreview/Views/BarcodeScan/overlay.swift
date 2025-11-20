    import SwiftUI

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
        ScannerOverlay()
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
    var body: some View {
        HStack(spacing: 4) {
            Image(isFlashon ? "flashon" : "flashoff")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(.white)

            Text(isFlashon ? "Flash On" : "Flash Off")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .padding(7.5)
        .background(
            .thinMaterial, in: .capsule
        )
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

struct Buttoncross: View {
    var body: some View {
        ZStack {
            Image(systemName: "xmark")
                .font(.system(size: 10))
                .foregroundColor(.white)
            
        }.padding(7.5)
            .background(
                .thinMaterial ,in: .capsule
            )
        
    }
}

struct ContentView4: View {
    let code: String
    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial.opacity(0.2))
                .frame(width: 300, height: 120)
            HStack{
                
                HStack(spacing: 47) {
                    
                    // ✅ Gradient Circle + Icon inside ZStack
                    ZStack {
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 68, height: 92)
                        
                    }
                    
                    
                    
                    
                }
                VStack(alignment :.leading,spacing: 8){
                   
                    ZStack{
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 185, height: 25)
                        Text("Scanned: \(code)")
                            .font(.footnote)
                            .foregroundColor(.white)
                        
                        
                    }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width: 132, height: 20)
                            .padding(.bottom , 7)
                   
                        RoundedRectangle(cornerRadius: 52)
                            .fill(.thinMaterial.opacity(0.4))
                            .frame(width:79    , height: 24)
                        
                    
                    
                }
            }
        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
    }
}

