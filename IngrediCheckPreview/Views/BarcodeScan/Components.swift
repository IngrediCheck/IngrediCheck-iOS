//
//  Components.swift
//  IngrediCheck
//
//  Created by Gaurav on 20/11/25.
//
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
                        Image("arrow-left")
                            .opacity(0.3)
                        
                        
                        
                        Image("arrow-left")
                            .opacity(0.6)
                        Image("arrow-left")
                            .opacity(1.0)
                    }
                    .font(.system(size: 18))
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

//#Preview {
//    CameraSwipeButton(mode: .constant(.scanner))
//}
