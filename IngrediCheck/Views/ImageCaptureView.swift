import SwiftUI
import AVFoundation
import Vision
import MLKitTextRecognition
import MLKitVision

extension View {
    @ViewBuilder
    func conditionalNavigationBarTitle(_ condition: Bool, title: String) -> some View {
        if condition {
            self.navigationBarTitle(title)
        } else {
            self
        }
    }
}

struct ImageCaptureView: View {
    
    @Binding var capturedImages: [ProductImage]
    let onSubmit: () -> Void
    let showClearButton: Bool
    let showTitle: Bool
    let showCancelButton: Bool

    @State private var cameraManager = CameraManager()
    @State private var showFocusToast = false
    @Environment(WebService.self) var webService
    @Environment(UserPreferences.self) var userPreferences
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                CameraPreview(session: cameraManager.session)
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.paletteSecondary, lineWidth: 0.8)
                    )
                
                // Educational toast
                if showFocusToast {
                    FocusEducationToast()
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .padding(.top)
            Text("Take photo of an Ingredient Label.")
                .padding(.top)
            Spacer()
            HStack {
                if capturedImages.isEmpty {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 100 * (3/4), height: 100)
                } else {
                    Image(uiImage: capturedImages.last!.image)
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fit)
                        .frame(width: 100 * (3/4), height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.paletteSecondary, lineWidth: 0.8)
                        )
                }
                Spacer()
                Button(action: {
                    capturePhoto()
                }, label: {
                    Image(systemName: "circle.dotted.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                })
                Spacer()
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 100 * (3/4), height: 100)
            }
            .padding(.bottom)
        }
        .navigationBarItems(
            leading: Group {
                if showClearButton {
                    clearButton
                }
                if showCancelButton {
                    cancelButton
                }
            },
            trailing: Group {
                if !showCancelButton || !capturedImages.isEmpty {
                    if showClearButton {
                        checkButton
                    } else {
                        submitButton
                    }
                }
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .conditionalNavigationBarTitle(showTitle, title: "Add Photos")
        .onAppear {
            cameraManager.setupSession()
            
            // Show focus toast every time camera opens with fade in animation
            withAnimation(.easeIn(duration: 0.3)) {
                showFocusToast = true
            }
            
            // Auto-dismiss after 4 seconds with fade out animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showFocusToast = false
                }
            }
        }
        .onDisappear {
            capturedImages = []
            cameraManager.stopSession()
        }
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            deleteCapturedImages()
            dismiss()
        }
    }
    
    private var clearButton: some View {
        Button("Clear") {
            deleteCapturedImages()
        }
        .disabled(capturedImages.isEmpty)
        .foregroundStyle(capturedImages.isEmpty ? .clear : .paletteAccent)
    }
    
    private var submitButton: some View {
        Button("Submit") {
            onSubmit()
        }
    }

    private var checkButton: some View {
        Button("Check") {
            onSubmit()
        }
        .disabled(capturedImages.isEmpty)
        .foregroundStyle(capturedImages.isEmpty ? .clear : .paletteAccent)
    }
    
    func capturePhoto() {
        cameraManager.capturePhoto { image in
            if let image = image {
                
                let ocrTask =
                    if case OcrModel.googleMLKit = userPreferences.ocrModel {
                        startMLKitOCRTask(image: image)
                    } else {
                        startOCRTask(image: image)
                    }
                let uploadTask = startUploadTask(image: image)
                let barcodeDetectionTask = startBarcodeDetectionTask(image: image)

                withAnimation {
                    capturedImages.append(ProductImage(
                        image: image,
                        ocrTask: ocrTask,
                        uploadTask: uploadTask,
                        barcodeDetectionTask: barcodeDetectionTask))
                }
            }
        }
    }
    
    func startUploadTask(image: UIImage) -> Task<String, Error> {
        Task {
            try await webService.uploadImage(image: image)
        }
    }
    
    func startOCRTask(image: UIImage) -> Task<String, Error> {
        Task {
            guard let cgImage = image.cgImage else {
                return ""
            }
            
            var imageText = ""
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    fatalError("Received invalid observations")
                }
                
                for observation in observations {
                    guard let bestCandidate = observation.topCandidates(1).first else {
                        print("No candidate")
                        continue
                    }
                    
                    imageText += bestCandidate.string
                    imageText += "\n"
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            return imageText
        }
    }
    
    func startMLKitOCRTask(image: UIImage) -> Task<String, Error> {
        Task {
            let visionImage = VisionImage(image: image)
            visionImage.orientation = image.imageOrientation
            let textRecognizer = TextRecognizer.textRecognizer()
            let result = try await textRecognizer.process(visionImage)
            print(result)
            return result.blocks.map({ return $0.text }).joined(separator: "\n")
        }
    }

    func startBarcodeDetectionTask(image: UIImage) -> Task<String?, Error> {
        Task {
            guard let cgImage = image.cgImage else {
                return nil
            }

            let request = VNDetectBarcodesRequest()
            request.symbologies = [.ean8, .ean13]
            request.coalesceCompositeSymbologies = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                guard let results = request.results as [VNBarcodeObservation]?, !results.isEmpty else {
                    return nil
                }
                
                return results.first?.payloadStringValue
            } catch {
                print("Failed to perform barcode detection: \(error)")
                return nil
            }
        }
    }
    
    func deleteCapturedImages() {
        let imagesToDelete = capturedImages
        
        withAnimation {
            capturedImages = []
        }

        Task {
            var filesToDelete: [String] = []
            for productImage in imagesToDelete {
                filesToDelete.append(try await productImage.uploadTask.value)
                _ = try await productImage.ocrTask.value
            }
            try await webService.deleteImages(imageFileNames: filesToDelete)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    var session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(session: session)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update code here
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer
    var session: AVCaptureSession
    private var persistentFocusIndicator: UIView?
    private var focusPoint: CGPoint
    
    init(session: AVCaptureSession) {
        self.session = session
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        // Initialize focus point at center (0.5, 0.5)
        self.focusPoint = CGPoint(x: 0.5, y: 0.5)
        super.init(frame: .zero)
        
        self.previewLayer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(self.previewLayer)
        
        // Add tap gesture for tap-to-focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        self.addGestureRecognizer(tapGesture)
        
        // Setup persistent focus indicator
        setupPersistentFocusIndicator()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
        
        // Update persistent focus indicator position
        updatePersistentFocusIndicatorPosition()
    }
    
    private func setupPersistentFocusIndicator() {
        // Create persistent focus indicator
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        indicator.layer.borderColor = UIColor.systemYellow.cgColor
        indicator.layer.borderWidth = 2.0
        indicator.layer.cornerRadius = 35
        indicator.alpha = 0.7
        indicator.backgroundColor = .clear
        
        self.addSubview(indicator)
        self.persistentFocusIndicator = indicator
        
        // Add subtle pulse animation
        addPulseAnimation(to: indicator)
    }
    
    private func addPulseAnimation(to view: UIView) {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.5
        pulseAnimation.fromValue = 0.95
        pulseAnimation.toValue = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        view.layer.add(pulseAnimation, forKey: "pulse")
    }
    
    private func updatePersistentFocusIndicatorPosition() {
        guard let indicator = persistentFocusIndicator else { return }
        
        // Convert normalized focus point (0-1) to view coordinates
        let viewPoint = CGPoint(
            x: focusPoint.x * bounds.width,
            y: focusPoint.y * bounds.height
        )
        
        indicator.center = viewPoint
    }
    
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let tapPoint = gesture.location(in: self)
        
        // Convert tap point to camera coordinates (0-1 range)
        let cameraFocusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
        
        // Update persistent indicator position
        self.focusPoint = CGPoint(
            x: tapPoint.x / bounds.width,
            y: tapPoint.y / bounds.height
        )
        
        // Animate persistent indicator to new position
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.updatePersistentFocusIndicatorPosition()
        }
        
        // Get the camera device from the session
        guard let device = session.inputs.first as? AVCaptureDeviceInput else {
            return
        }
        
        // Apply focus
        do {
            try device.device.lockForConfiguration()
            
            if device.device.isFocusPointOfInterestSupported && device.device.isFocusModeSupported(.autoFocus) {
                device.device.focusPointOfInterest = cameraFocusPoint
                device.device.focusMode = .continuousAutoFocus
            }
            
            if device.device.isExposurePointOfInterestSupported && device.device.isExposureModeSupported(.autoExpose) {
                device.device.exposurePointOfInterest = cameraFocusPoint
                device.device.exposureMode = .continuousAutoExposure
            }
            
            device.device.unlockForConfiguration()
            
            // Show temporary visual feedback (confirmation animation)
            showFocusIndicator(at: tapPoint)
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        // Create a focus indicator view
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.layer.borderColor = UIColor.systemYellow.cgColor
        focusView.layer.borderWidth = 2.0
        focusView.layer.cornerRadius = 40
        focusView.alpha = 0.0
        
        self.addSubview(focusView)
        
        // Animate the focus indicator
        UIView.animate(withDuration: 0.3, animations: {
            focusView.alpha = 1.0
            focusView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, animations: {
                focusView.alpha = 0.0
            }) { _ in
                focusView.removeFromSuperview()
            }
        }
    }
}

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    var session = AVCaptureSession()
    var photoOutput = AVCapturePhotoOutput()
    var completion: ((UIImage?) -> Void)?
    
    func focusOnPoint(device: AVCaptureDevice, point: CGPoint) {
        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
    }

    func setupSession() {
        session.sessionPreset = .photo
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera available.")
            return
        }
        
        do {
            
            // Enable continuous auto-focus on center point
            focusOnPoint(device: backCamera, point: CGPoint(x: 0.5, y: 0.5))

            let input = try AVCaptureDeviceInput(device: backCamera)
            if session.canAddInput(input) {
                session.addInput(input)
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                }
            }
            Task {
                session.startRunning()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("photoOutput callback received error: \(error)")
        } else {
            if let completion = self.completion {
                if let imageData = photo.fileDataRepresentation(),
                   let uiImage = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        completion(uiImage)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
}

// MARK: - Focus Education Toast

struct FocusEducationToast: View {
    var body: some View {
        Text("Tap somewhere to change the focus")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
            )
    }
}
