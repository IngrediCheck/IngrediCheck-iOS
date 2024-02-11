import SwiftUI
import AVFoundation
import Vision

struct ImageCaptureView: View {
    @Binding var routes: [CapturedItem]
    @State private var cameraManager = CameraManager()
    @State private var capturedImages: [ProductImage] = []

    var body: some View {
        VStack(spacing: 0) {
            CameraPreview(session: cameraManager.session)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.paletteSecondary, lineWidth: 0.8)
                )
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
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100 * (3/4), height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Spacer()
                Button(action: {
                    capturePhoto()
                }, label: {
                    Image(systemName: "circle.dotted.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.paletteAccent)
                })
                Spacer()
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 100 * (3/4), height: 100)
            }
            .padding(.bottom)
        }
        .navigationBarItems(
            leading:
                Button("Cancel") {
                    capturedImages = []
                }
                .disabled(capturedImages.isEmpty)
                .foregroundStyle(capturedImages.isEmpty ? .clear : .paletteAccent),
            trailing:
                Button("Done") {
                    routes.append(.productImages(capturedImages))
                }
                .disabled(capturedImages.isEmpty)
                .foregroundStyle(capturedImages.isEmpty ? .clear : .paletteAccent)
        )
        .onAppear {
            capturedImages = []
            cameraManager.setupSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    func capturePhoto() {
        cameraManager.capturePhoto { image in
            if let image = image {
                
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
                
                let handler = VNImageRequestHandler(cgImage: (image.cgImage)!, options: [:])
                try? handler.perform([request])

                capturedImages.append(ProductImage(image: image, imageOCRText: imageText))
            }
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
    
    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        
        self.previewLayer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(self.previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
    }
}

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    var session = AVCaptureSession()
    var photoOutput = AVCapturePhotoOutput()
    var completion: ((UIImage?) -> Void)?
    
    func setupSession() {
        session.sessionPreset = .photo
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera available.")
            return
        }
        
        do {
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
        if let completion = self.completion {
            if let imageData = photo.fileDataRepresentation(),
               let uiImage = UIImage(data: imageData) {
                completion(uiImage)
            } else {
                completion(nil)
            }
        }
    }
}
