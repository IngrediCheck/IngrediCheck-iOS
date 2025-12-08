//
//  AllergySummaryCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct MyIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.13143*width, y: height))
        path.addCurve(to: CGPoint(x: 0, y: 0.88265*height), control1: CGPoint(x: 0.05884*width, y: height), control2: CGPoint(x: 0, y: 0.94746*height))
        path.addLine(to: CGPoint(x: 0, y: 0.11735*height))
        path.addCurve(to: CGPoint(x: 0.13143*width, y: 0), control1: CGPoint(x: 0, y: 0.05254*height), control2: CGPoint(x: 0.05884*width, y: 0))
        path.addLine(to: CGPoint(x: 0.86857*width, y: 0))
        path.addCurve(to: CGPoint(x: width, y: 0.11735*height), control1: CGPoint(x: 0.94115*width, y: 0), control2: CGPoint(x: width, y: 0.05254*height))
        path.addLine(to: CGPoint(x: width, y: 0.59843*height))
        path.addCurve(to: CGPoint(x: 0.8531*width, y: 0.72959*height), control1: CGPoint(x: width, y: 0.67087*height), control2: CGPoint(x: 0.93423*width, y: 0.72959*height))
        path.addCurve(to: CGPoint(x: 0.70621*width, y: 0.86075*height), control1: CGPoint(x: 0.77198*width, y: 0.72959*height), control2: CGPoint(x: 0.70621*width, y: 0.78831*height))
        path.addLine(to: CGPoint(x: 0.70621*width, y: 0.8648*height))
        path.addCurve(to: CGPoint(x: 0.55478*width, y: height), control1: CGPoint(x: 0.70621*width, y: 0.93947*height), control2: CGPoint(x: 0.63841*width, y: height))
        path.addLine(to: CGPoint(x: 0.13143*width, y: height))
        path.closeSubpath()
        return path
    }
}

struct AllergySummaryCard: View {
    @State private var isEditableCanvasPresented: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text("25% Allergies")
                .font(ManropeFont.regular.size(8))
                .foregroundStyle(.grayScale130)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.grayScale30, in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale70)
                )
            
            Text("\"Your family avoids 🥜, dairy, 🦀, eggs, gluten, red meat 🥩, alcohol, making meal choices \nsimpler and \nsafer for \neveryone.\"")
                .font(ManropeFont.bold.size(14))
                .foregroundStyle(.grayScale140)
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 17)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            MyIcon()
                .fill(.grayScale10)
                
                .overlay(
                    MyIcon()
                        .stroke(lineWidth: 0.25)
                        .foregroundStyle(.grayScale60)
                        
                )
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            Button(action: {
                isEditableCanvasPresented = true
            }) {
                GreenCircle(iconName: "arrow-up-right",iconSize: 20, circleSize: 37)
                    .padding(3)
            }
            .buttonStyle(.plain)
            , alignment: .bottomTrailing
        )
        .sheet(isPresented: $isEditableCanvasPresented) {
            EditableCanvasView()
        }
    }
}

#Preview {
    AllergySummaryCard()
}
