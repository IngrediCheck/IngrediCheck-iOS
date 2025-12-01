
import SwiftUI

enum CameraMode {
    case scanner
    case photo
}

struct CameraSwipeButton: View {
    @Binding var mode: CameraMode
    @State private var isTapped = false
    @State private var isTapped1 = false
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack{
            ZStack {
                // Background Card
                RoundedRectangle(cornerRadius: 41)
                    .fill(.thinMaterial.opacity(0.4))
                    .frame(width: 229, height: 66)
                
                // Inner content
                HStack {
                   
                    // MARK: Left circle (Barcode)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isTapped = true
                            mode = .scanner
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isTapped = false
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    mode == .scanner ?
                                    AnyShapeStyle(LinearGradient(
                                        colors: [Color(hex: "#9DCF10"), Color(hex: "#6B8E06")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )) :
                                        AnyShapeStyle(Color.white.opacity(0.15))
                                )
                                .frame(width: 58.60, height: 58.60,)
                                .scaleEffect(isTapped ? 0.9 : 1.0)
                            Image("iconoir_scan-barcode")
                                .foregroundColor(.white)
                                .font(.system(size: 28))
                            
                            Text("Scanner")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                                .offset(y: UIScreen.main.bounds.height * 0.05)
                        }
//                        .background(.red)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(
//                        minLength: 12
                    )
                    
                    // MARK: Middle icons (shimmer + independent rotation)
                    ArrowSwipeShimmer(mode: mode)
                    
                    Spacer(
//                        minLength: 12
                    )
                    
                    // MARK: Right circle (Camera)
                    Button(action: {
                        withAnimation(.smooth(duration: 0.18)) {
                            isTapped1 = true
                            mode = .photo
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.smooth(duration: 0.18)) {
                                isTapped1 = false
                            }
                        }
                    }) {
                        ZStack() {
                            Circle()
                                .fill(
                                    mode == .photo ?
                                    AnyShapeStyle(LinearGradient(
                                        colors: [Color(hex: "#9DCF10"), Color(hex: "#6B8E06")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )) :
                                        AnyShapeStyle(.thinMaterial.opacity(0.5))
                                )
                                .frame(width: 58.60, height: 58.60)
                                .scaleEffect(isTapped1 ? 0.9 : 1.0)
                            Image("cameracapture")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                            
                            Text("Photo")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                                .offset(y: UIScreen.main.bounds.height * 0.05)
                        }
//                        .background(.red)
                    }
                    .buttonStyle(.plain)
                    
                }
                .padding(.horizontal, 3.5)
                .frame(width: 229)
                // subtle visual slide effect while dragging (keeps circles visually centered)
                .offset(x: dragOffset * 0.2)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dragOffset)
                
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        // live drag translation, tightly clamped so content stays visually centered
                        let translation = value.translation.width
                        let clamped = max(-15, min(15, translation))
                        state = clamped
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 30
                        let translation = value.translation.width
                        
                        if translation > threshold {
                            // swipe right -> go to photo mode (move selection to the right circle)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                mode = .photo
                            }
                        } else if translation < -threshold {
                            // swipe left -> go to scanner mode (move selection to the left circle)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                mode = .scanner
                            }
                        }
                    }
            )
            // keep circles visually inside the rounded pill while sliding
//            .clipShape(RoundedRectangle(cornerRadius: 46))
            //           .swipeShimmer()
            
            
//            HStack(){
//                Text("Scanner")
//                Spacer()
//                Text("Photo")
//            }
//            
//            .frame(maxWidth:229)
//            .foregroundColor(Color.white)
//            .font(.system(size: 11))
//            .fontWeight(.regular)
//            .padding(.leading , 40)
//            .padding(.trailing, 40)
          
            
            
            
        }
    }
}

struct cameraGuidetext: View {
    var body: some View {
        
        
        
        
        
        
        // Icon + Text vertically stacked
        HStack(spacing: 8,) {
            Image("lucide_scan-line"
            )
            .font(.system(size: 20))
            .foregroundColor(.white)
            
            Text("Scanning Products")
                .font(.system(size : 12))
                .foregroundColor(.white)
        }
        .frame(height: 36)
        .padding(.horizontal)
        .background(
            .thinMaterial.opacity(0.5) ,in: .capsule
            //
            
        )
        
        
    }
    
}
#Preview{
    cameraGuidetext()
}
struct FoundNotFoundView : View {
    var body: some View {
        
        // Icon + Text vertically stacked
        HStack(spacing: 8,) {
            Image("charm_circle-cross 1")
                .font(.system(size: 20))
                .foregroundColor(.white)
            
            Text("Got it! Scanned Red Bull Energy Drink")
                .font(.system(size : 12))
                .foregroundColor(.white)
        }
        .frame(height: 36)
        .padding(.horizontal,16)
        .background(
            .thinMaterial ,in: .capsule
            
            
        )
        
        
    }
    
}

struct AnalysingCard: View {
    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial.opacity(0.5))
                .frame(width: 300, height: 120)
            HStack{
                
                
                
                // ✅ Gradient Circle + Icon inside ZStack
                ZStack {
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .frame(width: 68, height: 92)
                    
                }
                .padding(.trailing , 12)
                
                
                
                
                VStack(alignment :.leading,){
                    
                    
                    Text( "Red Bull Energy Drink")
                        .font(.system(size : 16))
                        .foregroundColor(.white)
                        .fontWeight( .semibold)
                    
                    HStack(spacing : 8){
                        
                        ProgressView() // default spinner
                            .progressViewStyle(CircularProgressViewStyle())
                        //                              .foregroundStyle(.thinMaterial)
                            .tint( LinearGradient(
                                colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            ) // 👈 visible but still "material" looking
                        
                            .scaleEffect(1) // make it a bit bigger
                        
                        Text("Fetching details")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#A6A6A6"), Color(hex: "#818181")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .fontWeight(.semibold)
                        
                    }
                    .padding(8)
                    .background(
                        Capsule()
                            .fill(
                                .bar
                            )
                        
                    )
                    
                    
                    
                }
                .padding(.trailing , 4)
                
                Image("iconamoon_arrow-up-2-duotone")
            }
        }
        //        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea()) // background for contrast
    }
}

// ContentView4 is defined in `overlay.swift` and reused from there.
#Preview{
    AnalysingCard()
}

// MARK: - Camera translucent bar (for use over camera preview)

struct CameraTranslucentBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26.75)
            .fill(Color(hex: "#E8E8E8").opacity(0.2)) // #E8E8E833
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 26.75)
            )
            .frame(height: 53.5)
    }
}



struct ArrowSwipeShimmer: View {
    @State private var phase: CGFloat = -1
    private let animationDuration: Double = 1.4
    var mode: CameraMode
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Image("right-arrow")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 11, height: 21)
                    .foregroundColor(.white)
                    .opacity(0.4) // base arrow look
                    .rotationEffect(.degrees(mode == .photo ? 180 : 0))
                    .animation(
                        .easeInOut(duration: 0.24)
                        .delay(0.04 * Double(index)),
                        value: mode
                    )
            }
        }
        .overlay(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.6),
                    Color.white.opacity(0.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 42)
            .offset(x: phase * 42)
        )
        .mask(
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Image("right-arrow")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 11, height: 21)
                        .rotationEffect(.degrees(mode == .photo ? 180 : 0))
                        .animation(
                            .easeInOut(duration: 0.24)
                            .delay(0.04 * Double(index)),
                            value: mode
                        )
                }
            }
        )
        .onAppear { startShimmer() }
        .onChange(of: mode) { _ in
            // Restart shimmer when mode changes so the light never "dies" after a swipe
            startShimmer()
        }
    }
    
    private func startShimmer() {
        phase = -1
        withAnimation(
            Animation
                .linear(duration: animationDuration)
                .delay(0.4)
                .repeatForever(autoreverses: false)
        ) {
            phase = 1
        }
    }
}

struct SwipeShimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.grayScale70.opacity(0.0),
                        Color.grayScale70.opacity(0.3),
                        Color.grayScale70.opacity(0.3),
                        Color.grayScale70.opacity(0.8),
                        
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .scaleEffect(x: 1.5) // wider highlight
                    .offset(x: phase * 180) // shimmer movement
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    Animation
                        .linear(duration: 1.8)
                        .repeatForever(autoreverses: false) // <— IMPORTANT (left-right-left)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func swipeShimmer() -> some View {
        self.modifier(SwipeShimmer())
    }
}

//#Preview {
//    ZStack{
//        OutputCard()
//        //        CameraSwipeButton(mode: .constant(.photo))
//        //        ContentView6()
//    }.frame(maxWidth: .infinity, maxHeight: .infinity)
//        .ignoresSafeArea()
//        .background(.black)
//}
//
//#Preview("CameraTranslucentBar") {
//    ZStack {
//        // Simulated camera background
//        Color.black
//            .ignoresSafeArea()
//        
//        VStack {
//            Spacer()
//            CameraTranslucentBar()
//                .padding(.horizontal, 40)
//                .padding(.bottom, 40)
//        }
//    }
//}

#Preview {
    ZStack {
        Color.gray
        CameraSwipeButton(mode: .constant(.photo))
    }
}
