import AVFoundation

func requestCameraAccess(completion: @escaping (Bool) -> Void) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
            completion(granted)
        }
    }
}
