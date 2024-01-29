import SwiftUI
import AVFoundation
import Vision

func buttonImage(systemName: String, foregroundColor: Color) -> some View {
    Image(systemName: systemName)
        .frame(width: 20, height: 20)
        .font(.title3.weight(.thin))
        .foregroundColor(foregroundColor)
}

struct CloseButton : View {

    var disableClose: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Button(action: {
            dismiss()
        }, label: {
            buttonImage(systemName: "x.circle", foregroundColor: disableClose ? .gray : .paletteAccent)
        })
        .disabled(disableClose)
    }
}

struct ImageCaptureView: View {
    @Binding var image: UIImage?
    @Binding var imageOCRText: String?
    var cameraManager = CameraManager()

    var body: some View {
        NavigationStack {
            VStack {
                CameraPreview(session: cameraManager.session)
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.paletteSecondary, lineWidth: 0.8)
                    )
                Spacer()
                Button(action: {
                    capturePhoto()
                }, label: {
                    Image(systemName: "circle.dotted.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.paletteAccent)
                })
            }
            .padding()
            .navigationBarItems(trailing: CloseButton())
            .navigationTitle("Capture photo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cameraManager.setupSession()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
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

                self.image = image
                self.imageOCRText = imageText
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
                    Task {
                        session.startRunning()
                    }
                }
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
