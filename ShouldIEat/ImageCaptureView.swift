//
//  ImageCaptureView.swift
//  BeforeIForget
//
//  Created by sanket patel on 7/15/23.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit
import Vision

struct ImageCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var imageOCRText: String?
    @Environment(\.presentationMode) var presentationMode

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding var image: UIImage?
        @Binding var imageText: String?
        @Binding var presentationMode: PresentationMode

        init(image: Binding<UIImage?>, imageText: Binding<String?>, presentationMode: Binding<PresentationMode>) {
            _image = image
            _imageText = imageText
            _presentationMode = presentationMode
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                image = selectedImage
                
                let request = VNRecognizeTextRequest { request, error in
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        fatalError("Received invalid observations")
                    }
                    
                    var text = ""

                    for observation in observations {
                        guard let bestCandidate = observation.topCandidates(1).first else {
                            print("No candidate")
                            continue
                        }
                        
                        text += bestCandidate.string
                        text += "\n"
                    }
                    
                    self.imageText = text
                }
                
                let handler = VNImageRequestHandler(cgImage: (image?.cgImage)!, options: [:])
                try? handler.perform([request])
            }

//            presentationMode.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            presentationMode.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(image: $image, imageText: $imageOCRText, presentationMode: presentationMode)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImageCaptureView>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.showsCameraControls = true
        picker.mediaTypes = [UTType.image.identifier]
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImageCaptureView>) {
        // No need to update
    }
}
