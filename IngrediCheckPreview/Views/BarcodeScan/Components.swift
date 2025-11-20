
import SwiftUI

enum CameraMode {
    case scanner
    case photo
}

struct CameraSwipeButton: View {
    @Binding var mode: CameraMode
    @State private var isTapped = false
    @State private var isTapped1 = false
    
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
                    
                    // MARK: Middle icons
                    HStack(spacing: 8) {
                        Image("right-arrow")
                            .resizable()
                            .frame(width: 11, height: 21)
                            .opacity(0.3)
                        Image("right-arrow")
                            .resizable()
                            .frame(width: 11, height: 21)
                            .opacity(0.6)
                        Image("right-arrow")
                            .resizable()
                            .frame(width: 11, height: 21)
                            .opacity(1.0)
                    }
                 
                    
                    .foregroundColor(.white)
                    
                    Spacer(minLength: 12)
                    
                    // MARK: Right circle (Camera)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isTapped1 = true
                            mode = .photo
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.18)) {
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
                .frame(width: 272)
            }

            
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

#Preview {
    ZStack{
        ContentView6()
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(.black)
}

