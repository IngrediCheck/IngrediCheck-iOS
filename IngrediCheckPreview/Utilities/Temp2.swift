//
//  Temp2.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 03/10/25.
//
import SwiftUI

struct PhotoStackView: View {
    @State private var photos: [Photo] = [
        Photo(image: "image 1"),
        Photo(image: "image 2"),
        Photo(image: "image 3"),
        Photo(image: "image 4"),
        Photo(image: "image 5")
    ]
    
    @State private var currentOffset: CGSize = .zero
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    let isTop = index == photos.count - 1
                    let backIndex = photos.count - 1 - index
                    let offsetStep: CGFloat = 15
                    let rotationStep: Double = 5
                    
                    CardView(photo: photo)
                        .frame(width: UIScreen.main.bounds.width - 60, height: 200)
                        .rotationEffect(
                            .degrees(isTop ? Double(currentOffset.width / 10) : Double(backIndex) * rotationStep),
                            anchor: .center
                        )
                        .offset(
                            x: isTop ? currentOffset.width : CGFloat(backIndex) * offsetStep,
                            y: isTop ? currentOffset.height : CGFloat(backIndex) * offsetStep
                        )
                        .zIndex(Double(index))
                        .gesture(
                            isTop ?
                            DragGesture()
                                .onChanged { gesture in
                                    currentOffset = gesture.translation
                                }
                                .onEnded { gesture in
                                    let dragDistance = sqrt(pow(gesture.translation.width, 2) + pow(gesture.translation.height, 2))
                                    if dragDistance > 120 {
                                        withAnimation(.spring()) {
                                            currentOffset = CGSize(width: gesture.translation.width * 5,
                                                                   height: gesture.translation.height * 5)
                                        }
                                        moveTopCardToBack(after: 0.3)
                                    } else {
                                        withAnimation(.spring()) {
                                            currentOffset = .zero
                                        }
                                    }
                                }
                            : nil
                        )
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            
            Spacer()
        }
        .background(Color.gray.opacity(0.1))
    }
    
    private func moveTopCardToBack(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let topCard = photos.removeLast()
            photos.insert(topCard, at: 0)
            currentOffset = .zero
        }
    }
}

struct CardView: View {
    let photo: Photo
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(radius: 5)
            
            Image(photo.image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct Photo: Identifiable {
    let id = UUID()
    let image: String
}


#Preview {
    PhotoStackView()
}
