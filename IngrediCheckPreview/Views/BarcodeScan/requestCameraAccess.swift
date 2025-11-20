import AVFoundation
import SwiftUI

func requestCameraAccess(completion: @escaping (Bool) -> Void) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
            completion(granted)
        }
    }
}

struct CameraPermisionView: View {
    @State var cameraAllowed: Bool = false
    @State var showDeniedAlert: Bool = false

    var body: some View {
        VStack {
            Button("Request Camera Accesss") {
                requestCameraAccess { granted in
                    if granted {
                        cameraAllowed = true
                    } else {
                        showDeniedAlert = true
                    }
                }
            }
        }
        .alert("Camera Access Denied", isPresented: $showDeniedAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}
