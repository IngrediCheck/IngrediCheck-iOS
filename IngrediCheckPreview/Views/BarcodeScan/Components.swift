
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
                RoundedRectangle(cornerRadius: 46)
                    .fill(.thinMaterial.opacity(0.5))
                    .frame(width: 261, height: 75)
                
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
                                .frame(width: 67, height: 67)
                                .scaleEffect(isTapped ? 0.9 : 1.0)
                            Image("iconoir_scan-barcode")
                                .foregroundColor(.white)
                                .font(.system(size: 28))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 12)
                    
                    // MARK: Middle icons (sequential swipe shimmer)
                    ArrowSwipeShimmer()
                        .rotationEffect(.degrees(mode == .photo ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: mode)
                    
                    Spacer(minLength: 12)
                    
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
                        ZStack {
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
                                .frame(width: 67, height: 67)
                                .scaleEffect(isTapped1 ? 0.9 : 1.0)
                            Image("cameracapture")
                                .foregroundColor(.white)
                                .font(.system(size: 22))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(width: 261)
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
            .clipShape(RoundedRectangle(cornerRadius: 46))
//           .swipeShimmer()

            
            HStack(){
                Text("Scanner")
                Spacer()
                Text("Photo")
            }
            .frame(maxWidth:212)
            .foregroundColor(Color.white)
            .font(.system(size: 11))
            .fontWeight(.regular)
            .padding(.horizontal , 16)
            .padding(.top, 4)
            
            
        }
    }
}

struct ContentView5: View {
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

struct ContentView6: View {
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
                              .tint(.gray) // 👈 visible but still "material" looking

                              .scaleEffect(1) // make it a bit bigger
                             
                        Text( "Fetching details")
                            .font(.system(size : 14))
                            .foregroundColor(.black
//                                LinearGradient(
//                                colors: [ Color(hex: "#9DCF10"), Color(hex: "#6B8E06")],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            )
                            )
                            .fontWeight( .semibold)
                        
                    }
                    .frame(width: 149 , height: 36)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#FFFFFF"), Color(hex: "#EAEAEA")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            
                    )
                    
                  
                    
                }
                .padding(.trailing , 4)
                
                Image(systemName: "iconamoon_arrow-up-2-duotone")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea()) // background for contrast
    }
}



struct ArrowSwipeShimmer: View {
    @State private var phase: CGFloat = -1
    private let animationDuration: Double = 1.4

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                Image("right-arrow")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 11, height: 21)
                    .foregroundColor(.white)
                    .opacity(0.4) // base arrow look
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
                ForEach(0..<3, id: \.self) { _ in
                    Image("right-arrow")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 11, height: 21)
                }
            }
        )
        .onAppear {
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

#Preview {
    ZStack{
        CameraSwipeButton(mode: .constant(.photo))
//        ContentView6()
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(.black)
}
