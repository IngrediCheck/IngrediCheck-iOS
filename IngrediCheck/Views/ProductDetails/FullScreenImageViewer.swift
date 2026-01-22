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

    // Swipe to dismiss state
    @State private var dismissOffset: CGFloat = 0
    @State private var isDismissing: Bool = false

    // Constants
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    private let dismissThreshold: CGFloat = 150

    var body: some View {
        ZStack {
            // Background - fades as user drags down
            Color.black
                .opacity(backgroundOpacity)
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

//                Spacer()

                // Zoom controls - positioned above thumbnail strip
                zoomControls
                    .padding(.bottom, images.count > 1 ? 12 : 40)
                
                // Bottom thumbnail strip
                if images.count > 1 {
                    thumbnailStrip
                        .padding(.bottom, 40)
                }
            }
            .offset(y: dismissOffset)
            .scaleEffect(dismissScale)
            .gesture(swipeToDismissGesture)
        }
        .statusBarHidden(true)
    }

    // MARK: - Dismiss Animation Properties

    private var backgroundOpacity: Double {
        let progress = min(abs(dismissOffset) / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.5)
    }

    private var dismissScale: CGFloat {
        let progress = min(abs(dismissOffset) / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.1)
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

            // Placeholder to maintain layout
            Color.clear
                .frame(width: 44, height: 44)
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

    private var swipeToDismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow swipe to dismiss when not zoomed
                guard scale <= 1.0 else { return }

                // Allow both up and down swipe
                let verticalMovement = value.translation.height

                // Apply resistance for upward swipes
                if verticalMovement < 0 {
                    dismissOffset = verticalMovement * 0.3
                } else {
                    dismissOffset = verticalMovement
                }
            }
            .onEnded { value in
                guard scale <= 1.0 else { return }

                let velocity = value.predictedEndTranslation.height - value.translation.height
                let shouldDismiss = abs(dismissOffset) > dismissThreshold || abs(velocity) > 500

                if shouldDismiss && dismissOffset > 0 {
                    // Dismiss with animation
                    isDismissing = true
                    withAnimation(.easeOut(duration: 0.2)) {
                        dismissOffset = UIScreen.main.bounds.height
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        dismiss()
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismissOffset = 0
                    }
                }
            }
    }

    // MARK: - Zoom Controls
    
    private var zoomControls: some View {
        HStack(spacing: 20) {
            // Zoom out button
            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .disabled(scale <= minScale)
            .opacity(scale <= minScale ? 0.5 : 1.0)
            
            // Zoom percentage badge (centered)
            Text("\(Int(scale * 100))%")
                .font(ManropeFont.semiBold.size(14))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
                .frame(minWidth: 60)
            
            // Zoom in button
            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .disabled(scale >= maxScale)
            .opacity(scale >= maxScale ? 0.5 : 1.0)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Zoom Actions
    
    private func zoomIn() {
        let increment: CGFloat = 0.5
        let newScale = min(scale + increment, maxScale)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = newScale
            lastScale = 1.0
            
            // Reset offset when zooming in from 1.0
            if scale == increment + 1.0 {
                offset = .zero
                lastOffset = .zero
            }
        }
    }
    
    private func zoomOut() {
        let decrement: CGFloat = 0.5
        var newScale = max(scale - decrement, minScale)
        
        // If zooming out to 1.0, reset everything
        if newScale <= minScale + 0.1 {
            newScale = minScale
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = newScale
            lastScale = 1.0
            
            // Reset offset if zoomed out to 1.0
            if newScale <= minScale {
                offset = .zero
                lastOffset = .zero
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

