import SwiftUI
import AVFoundation

/// UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer to display camera feed
struct BarcodeCameraPreview: UIViewRepresentable {
    
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
