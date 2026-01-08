//
//  FullScreenImageViewer.swift
//  IngrediCheck
//
//  Created on 05/01/26.
//

import SwiftUI

struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss

    let images: [ProductDetailView.ProductImage]
    @Binding var selectedIndex: Int
    var onFeedback: ((String, String) -> Void)?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    // Constants
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header with close button and reset
                header

                Spacer()

                // Image viewer with zoom
                TabView(selection: $selectedIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        GeometryReader { geometry in
                            ZStack {
                                // Image content
                                imageContent(for: images[index])
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .scaleEffect(index == selectedIndex ? scale : 1.0)
                                    .offset(index == selectedIndex ? offset : .zero)
                                    .gesture(
                                        index == selectedIndex ? magnificationGesture() : nil
                                    )
                                    .simultaneousGesture(
                                        index == selectedIndex ? dragGesture() : nil
                                    )
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedIndex) { oldValue, newValue in
                    // Reset zoom when switching images
                    if oldValue != newValue {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            resetZoom()
                        }
                    }
                }

                Spacer()

                // Bottom thumbnail strip
                if images.count > 1 {
                    thumbnailStrip
                        .padding(.bottom, 40)
                }
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            Text("\(selectedIndex + 1) / \(images.count)")
                .font(ManropeFont.semiBold.size(16))
                .foregroundColor(.white)

            Spacer()

            // Reset zoom button (only show if zoomed)
            if scale > 1.0 || offset != .zero {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .overlay(alignment: .trailing) {
            // Feedback buttons
            if let image = images[safe: selectedIndex], case .api(let locationInfo, let vote) = image, case .url(let url) = locationInfo {
                HStack(spacing: 12) {
                    // Thumbs Up
                    FeedbackButton(
                        type: .up,
                        isSelected: vote?.value == "up",
                        style: .overlay
                    ) {
                        onFeedback?(url.absoluteString, "up")
                    }

                    // Thumbs Down
                    FeedbackButton(
                        type: .down,
                        isSelected: vote?.value == "down",
                        style: .overlay
                    ) {
                        onFeedback?(url.absoluteString, "down")
                    }
                }
                .padding(.trailing, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Thumbnail Strip

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(images.indices, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedIndex = index
                        }
                    } label: {
                        imageContent(for: images[index])
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selectedIndex == index ? Color.white : Color.white.opacity(0.3),
                                        lineWidth: selectedIndex == index ? 3 : 1
                                    )
                                    .padding(.all, 1)
                            )
                            .opacity(selectedIndex == index ? 1.0 : 0.6)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Image Content Helper

    @ViewBuilder
    private func imageContent(for image: ProductDetailView.ProductImage) -> some View {
        switch image {
        case .local(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
        case .api(let location, _):
            HeaderImage(imageLocation: location)
        }
    }

    // MARK: - Gestures

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value

                // Calculate new scale
                var newScale = scale * delta

                // Clamp scale between min and max
                newScale = min(max(newScale, minScale), maxScale)

                scale = newScale
            }
            .onEnded { _ in
                lastScale = 1.0

                // If scale is close to min, snap back to 1.0
                if scale < minScale + 0.1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scale = minScale
                        offset = .zero
                    }
                }
            }
    }

    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow dragging when zoomed in
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset

                // If not zoomed, reset offset
                if scale <= 1.0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    // MARK: - Helper Methods

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var selectedIndex = 0

    let sampleImages: [ProductDetailView.ProductImage] = [
        .local(UIImage(named: "ram")!),
        .local(UIImage(systemName: "photo.fill")!),
        .local(UIImage(systemName: "photo.circle")!)
    ]

    FullScreenImageViewer(
        images: sampleImages,
        selectedIndex: $selectedIndex
    )
}
#endif

