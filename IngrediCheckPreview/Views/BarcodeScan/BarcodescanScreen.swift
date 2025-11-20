import SwiftUI
import AVFoundation
import UIKit
import Combine

struct CameraPreview: UIViewRepresentable {

    @ObservedObject var cameraManager: BarcodeCameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = UIScreen.main.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            if previewLayer.superlayer !== uiView.layer {
                uiView.layer.addSublayer(previewLayer)
            }
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            previewLayer.frame = uiView.bounds
        }
    }
}

struct CameraScreen: View {
    
    @StateObject var camera = BarcodeCameraManager()
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) var scenePhase
    @State private var isCaptured: Bool = false
    @State private var overlayRect: CGRect = .zero
    @State private var overlayContainerSize: CGSize = .zero
    @State private var codes: [String] = []
    @State private var scrollTargetCode: String?
    @State private var isUserDragging: Bool = false
    @State private var lastUserDragAt: Date? = nil
    @State private var mode: CameraMode = .scanner
    @State private var capturedPhoto: UIImage? = nil
    
    var body: some View {
        ZStack {
#if targetEnvironment(simulator)
            Color(.systemGray5)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Camera not available in Preview/Simulator")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                )
#endif
            CameraPreview(cameraManager: camera)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .onAppear {
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    cameraStatus = status
                    switch status {
                    case .authorized:
                        camera.startSession()
                    case .notDetermined:
                        requestCameraAccess { granted in
                            cameraStatus = granted ? .authorized : .denied
                            if granted { camera.startSession() }
                        }
                    case .denied, .restricted:
                        break
                    @unknown default:
                        break
                    }
                    camera.scanningEnabled = (mode == .scanner)
                    isCaptured = UIScreen.main.isCaptured
                }
                .onDisappear { camera.stopSession() }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        if cameraStatus == .authorized { camera.startSession() }
                    } else if newPhase == .background {
                        camera.stopSession()
                    }
                }
                .onChange(of: mode) { newMode in
                    camera.scanningEnabled = (newMode == .scanner)
                }
                .onChange(of: camera.isSessionRunning) { running in
                    if running {
                        camera.updateRectOfInterest(overlayRect: overlayRect, containerSize: overlayContainerSize)
                    }
                }
                .onReceive(camera.$scannedBarcode.compactMap { $0 }) { code in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if let idx = codes.firstIndex(of: code) {
                            scrollTargetCode = codes[idx]
                        } else {
                            codes.insert(code, at: 0)
                            if codes.count > 10 { codes.removeLast(codes.count - 10) }
                            scrollTargetCode = code
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                    isCaptured = UIScreen.main.isCaptured
                }
            
            if mode == .scanner {
                ScannerOverlay(onRectChange: { rect, size in
                    overlayRect = rect
                    overlayContainerSize = size
                    camera.updateRectOfInterest(overlayRect: rect, containerSize: size)
                })
                .environmentObject(camera)
            } else {
                // Photo mode overlay: show last captured image as a floating thumbnail if available
                EmptyView()
            }
            
            VStack {
                HStack {
                    Buttoncross()
                    Spacer()
                    Flashcapsul()
                    
                }
                .padding(.horizontal,20)
                .padding(.bottom,42)

                if let image = capturedPhoto {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                ContentView5()
                Spacer()
                CameraSwipeButton(mode: $mode)
                if mode == .photo {
                    Button(action: {
                        camera.capturePhoto { image in
                            if let image = image {
                                capturedPhoto = image
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 64, height: 64)
                            Circle()
                                .stroke(Color.black.opacity(0.4), lineWidth: 2)
                                .frame(width: 70, height: 70)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .zIndex(2)
            
            if mode == .scanner {
                VStack {
                    Spacer()
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(codes, id: \.self) { code in
                                    ContentView4(code: code)
                                        .id(code)
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                        .simultaneousGesture(
                                            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                                                .onEnded { value in
                                                    let t = value.translation
                                                    let promote: () -> Void = {
                                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                            if let idx = codes.firstIndex(of: code) { codes.remove(at: idx) }
                                                            codes.insert(code, at: 0)
                                                        }
                                                    }
                                                    // Only allow vertical swipe-up to promote to avoid fighting horizontal scroll
                                                    if abs(t.height) > 30 && abs(t.height) > abs(t.width) && t.height < 0 {
                                                        promote(); return
                                                    }
                                                }
                                        )
                                }
                            }
                            .padding(.horizontal, max((UIScreen.main.bounds.width - 300) / 2, 0))
                        }
                        // Track user drag on the scroll view to suppress auto-scroll while interacting
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                                .onChanged { _ in
                                    if !isUserDragging { isUserDragging = true }
                                }
                                .onEnded { _ in
                                    isUserDragging = false
                                    lastUserDragAt = Date()
                                }
                        )
                        .onChange(of: scrollTargetCode) { target in
                            guard let target else { return }
                            // Suppress auto-scroll if user is actively dragging or just dragged recently
                            let recentlyDragged: Bool = {
                                guard let last = lastUserDragAt else { return false }
                                return Date().timeIntervalSince(last) < 1.0
                            }()
                            guard !isUserDragging && !recentlyDragged else { return }
                            withAnimation(.easeInOut) { proxy.scrollTo(target, anchor: .center) }
                        }
                    }
                    .padding(.top, 243)
                }
                
                if cameraStatus == .denied || cameraStatus == .restricted {
                    VStack(spacing: 12) {
                        Text("Camera access is required")
                            .font(.headline)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                //            VStack {
                //                Spacer()
                ////                HStack {
                ////                    if let code = camera.scannedBarcode {
                ////                        Text("Scanned: \(code)")
                ////                            .font(.footnote)
                ////                            .padding(6)
                ////                            .background(.black.opacity(0.5))
                ////                            .foregroundColor(.white)
                ////                            .clipShape(RoundedRectangle(cornerRadius: 6))
                ////                    }
                ////                    if isCaptured {
                ////                        Text("Screen Recording/Mirroring Detected – iOS hides camera")
                ////                            .font(.footnote)
                ////                            .padding(6)
                ////                            .background(.red.opacity(0.7))
                ////                            .foregroundColor(.white)
                ////                            .clipShape(RoundedRectangle(cornerRadius: 6))
                ////                    }
                ////                    Spacer()
                ////                }
                //            }
                //            .padding()
            }
        }
    }
}

#Preview {
   CameraScreen()
}
