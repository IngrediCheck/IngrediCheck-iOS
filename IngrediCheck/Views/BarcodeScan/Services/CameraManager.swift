import AVFoundation
import UIKit
import Combine


class BarcodeCameraManager: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
    let session  = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.queue", qos: .userInitiated)
    
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var scannedBarcode: String?
    @Published var isSessionRunning: Bool = false
    @Published var debugInfo: String = ""
    @Published var scanningEnabled: Bool = true
    var onBarcodeScanned: ((String) -> Void)?
    
    // Keep pipeline minimal for faster startup
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var outputsConfigured = false
    private var lastEmittedBarcode: String?
    private var lastHapticAt: Date?
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    
    override init() {
        super.init()
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRuntimeError(_:)),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionDidStartRunning(_:)),
                                               name: .AVCaptureSessionDidStartRunning,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionDidStopRunning(_:)),
                                               name: .AVCaptureSessionDidStopRunning,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionWasInterrupted(_:)),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionInterruptionEnded(_:)),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
    }

    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let completion = self.photoCaptureCompletion
        self.photoCaptureCompletion = nil
        guard error == nil else {
            print("[BarcodeCameraManager] photoOutput error: \(error!)")
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        DispatchQueue.main.async { completion?(image) }
    }
    private func selectBackCamera() -> AVCaptureDevice? {
        // Use the most compatible and fastest default
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func configureSession() {
        session.beginConfiguration()
        // Always balance begin/commit, even if we early-return.
        defer {
            session.commitConfiguration()
        }
        session.sessionPreset = .medium
        guard let device = selectBackCamera(),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("Camera input error")
            return
        }
        session.addInput(input)

        // Improve perceived quality: enable continuous AF/AE/WB
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
        } catch {
            print("[BarcodeCameraManager] Could not lock device for configuration: \(error)")
        }
        // Provide active capture device + queue to FlashManager for safe torch control
        FlashManager.shared.configure(with: device, queue: sessionQueue)

        // Configure metadata output once during initial setup to avoid reconfiguration later.
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: sessionQueue)
            let requested: [AVMetadataObject.ObjectType] = [  .ean13,
                                                              .ean8,
                                                              .code128,
                                                              .code39,
                                                              .code93,
                                                              .upce,
                                                              .qr
            ]
            let available = metadataOutput.availableMetadataObjectTypes
            let supported = requested.filter { available.contains($0) }
            metadataOutput.metadataObjectTypes = supported
            outputsConfigured = true
        }

        // Configure photo output for still capture (used in photo mode).
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        print("[BarcodeCameraManager] Before commit: inputs=\(session.inputs.count) outputs=\(session.outputs.count)")
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.needsDisplayOnBoundsChange = true
        DispatchQueue.main.async { self.previewLayer = preview }
    }

    private func bumpPresetToHighIfPossible() {
        sessionQueue.async {
            guard self.session.canSetSessionPreset(.high) else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            self.session.commitConfiguration()
            print("[BarcodeCameraManager] Bumped session preset to .high")
        }
    }
    
    func updateRectOfInterest(overlayRect: CGRect, containerSize: CGSize) {
        // Use full-frame recognition so barcodes can be detected anywhere
        sessionQueue.async {
            self.metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
            print("[BarcodeCameraManager] rectOfInterest=full")
        }
    }
    
    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
            // isRunning may not reflect immediately. We'll rely on notifications
            // but also set a delayed check as a fallback for UI feedback.
            let delay = DispatchTime.now() + 0.1
            self.sessionQueue.asyncAfter(deadline: delay) {
                let running = self.session.isRunning
                DispatchQueue.main.async {
                    self.isSessionRunning = running
                    if let connection = self.previewLayer?.connection, connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    self.previewLayer?.videoGravity = .resizeAspectFill
                    let info = "inputs=\(self.session.inputs.count) outputs=\(self.session.outputs.count) running=\(running)"
                    self.debugInfo = info
                    print("[BarcodeCameraManager] \(info)")
                    if !running { print("[BarcodeCameraManager] Session failed to start (timeout)") }
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }
    
    // MARK: - Photo capture
    /// Captures a still image from the active camera session.
    /// - Parameters:
    ///   - useFlash: When `true`, a photo flash will be used for this capture
    ///              if the device supports it. When `false`, the capture
    ///              happens without flash.
    ///   - completion: Called on the main thread with the resulting image, or
    ///                 `nil` if capture failed.
    func capturePhoto(useFlash: Bool = false, completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            guard self.session.isRunning else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.photoCaptureCompletion = completion
            
            let settings = AVCapturePhotoSettings()
            // Configure one-shot flash behaviour separate from the continuous torch
            // that is controlled by `FlashManager` in scanner mode.
            if self.photoOutput.supportedFlashModes.contains(.on) {
                settings.flashMode = useFlash ? .on : .off
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Barcode Delegate
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        // If scanning is temporarily disabled (e.g., in photo mode), ignore detections
        if !scanningEnabled {
            return
        }
        // If nothing is detected this frame, allow the same code to be recognized again next time it re-enters the frame
        if metadataObjects.isEmpty {
            self.lastEmittedBarcode = nil
            return
        }
        if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let value = object.stringValue {
            // Only emit when the value changes; prevents repeated triggers for the same visible code
            guard value != self.lastEmittedBarcode else { return }
            self.lastEmittedBarcode = value
            DispatchQueue.main.async {
                self.scannedBarcode = value
                self.onBarcodeScanned?(value)
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.success)
            }
        }
    }

    @objc private func handleRuntimeError(_ notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            print("AVCaptureSessionRuntimeError: \(error)")
        } else {
            print("AVCaptureSessionRuntimeError occurred")
        }
    }

    @objc private func handleSessionDidStartRunning(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isSessionRunning = true
            let info = "inputs=\(self.session.inputs.count) outputs=\(self.session.outputs.count) running=true"
            self.debugInfo = info
        }
        print("[BarcodeCameraManager] Session did start running")
        bumpPresetToHighIfPossible()
    }

    @objc private func handleSessionDidStopRunning(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isSessionRunning = false
        }
        print("[BarcodeCameraManager] Session did stop running")
    }

    @objc private func handleSessionWasInterrupted(_ notification: Notification) {
        print("[BarcodeCameraManager] Session was interrupted: \(notification.userInfo ?? [:])")
    }

    @objc private func handleSessionInterruptionEnded(_ notification: Notification) {
        print("[BarcodeCameraManager] Session interruption ended")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

class FlashManager {
    static let shared  = FlashManager()
    private init (){}
    private var device: AVCaptureDevice?
    private var queue: DispatchQueue?

    func configure(with device: AVCaptureDevice, queue: DispatchQueue) {
        self.device = device
        self.queue = queue
    }

    func toggleFlash(completion: ((Bool) -> Void)? = nil) {
        let act: (AVCaptureDevice) -> Void = { dev in
            guard dev.hasTorch else { return }
            do {
                try dev.lockForConfiguration()
                if dev.torchMode == .on {
                    dev.torchMode = .off
                } else {
                    try dev.setTorchModeOn(level: 1.0)
                }
                dev.unlockForConfiguration()
            } catch {
                print("Flash toggle failed: \(error)")
            }
        }
        if let dev = device, let q = queue {
            q.async {
                act(dev)
                let state = dev.hasTorch && dev.torchMode == .on
                if let completion = completion {
                    DispatchQueue.main.async { completion(state) }
                }
            }
        } else if let fallback = AVCaptureDevice.default(for: .video) {
            DispatchQueue.global(qos: .userInitiated).async {
                act(fallback)
                let state = fallback.hasTorch && fallback.torchMode == .on
                if let completion = completion {
                    DispatchQueue.main.async { completion(state) }
                }
            }
        }
    }
    
    func isFlashOn() -> Bool {
        let dev = device ?? AVCaptureDevice.default(for: .video)
        guard let d = dev, d.hasTorch else { return false }
        return d.torchMode == .on
    }
}
    




