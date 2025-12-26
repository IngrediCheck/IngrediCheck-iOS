//
//  UIImageExtensions.swift
//  IngrediCheck
//
//  Created on 13/12/25.
//

import UIKit

extension UIImage {
    /// Creates a deep copy of the image by rendering it to a new graphics context.
    /// This ensures the image data is fully retained and prevents EXC_BAD_ACCESS
    /// when the original image's CGImage is deallocated.
    /// Uses autoreleasepool to ensure proper memory management.
    /// - Returns: A new UIImage with its own copy of the pixel data
    func deepCopy() -> UIImage? {
        // CRITICAL: Capture cgImage immediately and validate it exists
        // Use autoreleasepool to ensure proper memory management
        return autoreleasepool {
            // Capture cgImage first - if this fails, the image is already deallocated
            guard let sourceCGImage = self.cgImage else {
                print("[UIImageExtensions] deepCopy: Image has no CGImage, returning nil")
                return nil
            }
            
            // Capture all properties immediately
            let size = self.size
            let scale = self.scale
            let orientation = self.imageOrientation
            
            guard size.width > 0 && size.height > 0,
                  size.width.isFinite && size.height.isFinite,
                  scale > 0 && scale.isFinite else {
                print("[UIImageExtensions] deepCopy: Invalid image size or scale, returning nil")
                return nil
            }
            
            // Create a new graphics context and render the image to create a deep copy
            // Use opaque=false to preserve transparency if needed
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            defer { UIGraphicsEndImageContext() }
            
            guard UIGraphicsGetCurrentContext() != nil else {
                print("[UIImageExtensions] deepCopy: Failed to get graphics context, returning nil")
                return nil
            }
            
            // Create UIImage from captured CGImage - this creates a new reference
            // Draw immediately to create the copy before any potential deallocation
            let imageToDraw = UIImage(cgImage: sourceCGImage, scale: scale, orientation: orientation)
            imageToDraw.draw(in: CGRect(origin: .zero, size: size))
            
            // Get the copied image - this should have its own pixel data now
            guard let copiedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                print("[UIImageExtensions] deepCopy: Failed to create copied image, returning nil")
                return nil
            }
            
            return copiedImage
        }
    }
    
    /// Composites the image with a background color, creating a circular image with the background visible behind transparent areas.
    /// - Parameter backgroundColorHex: Hex color string (with or without # prefix)
    /// - Returns: A new UIImage with the background color composited behind the image
    func compositedWithBackground(backgroundColorHex: String) -> UIImage? {
        // CRITICAL: Use autoreleasepool to ensure proper memory management
        // and prevent accessing deallocated CGImage
        return autoreleasepool {
            // Safety check: ensure image has valid dimensions and is not deallocated
            // Capture cgImage immediately - if this fails, the image is deallocated
            guard let cgImage = self.cgImage else {
                print("[UIImageExtensions] compositedWithBackground: Image has no CGImage, returning original")
                return self
            }
            
            // Validate cgImage is still valid by checking its width/height
            guard cgImage.width > 0 && cgImage.height > 0 else {
                print("[UIImageExtensions] compositedWithBackground: CGImage has invalid dimensions, returning original")
                return self
            }
        
            // Capture all properties immediately to prevent accessing deallocated objects
            let originalSize = self.size
            let scale = self.scale
            let orientation = self.imageOrientation
            
            guard originalSize.width > 0 && originalSize.height > 0,
                  originalSize.width.isFinite && originalSize.height.isFinite else {
                print("[UIImageExtensions] compositedWithBackground: Invalid image size (\(originalSize.width)x\(originalSize.height)), returning original image")
                return self
            }
            
            // Ensure we work with a square image (use the larger dimension)
            let maxDimension = max(originalSize.width, originalSize.height)
            guard maxDimension.isFinite && maxDimension > 0 else {
                print("[UIImageExtensions] compositedWithBackground: Invalid maxDimension, returning original")
                return self
            }
            
            let size = CGSize(width: maxDimension, height: maxDimension)
        
            // Parse hex color
            let hex = backgroundColorHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            guard !hex.isEmpty else {
                print("[UIImageExtensions] compositedWithBackground: Empty hex color, returning original image")
                return self
            }
            
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            let r, g, b: UInt64
            switch hex.count {
            case 3: // RGB (12-bit)
                (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: // RGB (24-bit)
                (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
            default:
                print("[UIImageExtensions] compositedWithBackground: Invalid hex color format (\(hex)), using black")
                (r, g, b) = (0, 0, 0)
            }
            
            let backgroundColor = UIColor(
                red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1.0
            )
            
            // Create a graphics context with safety checks
            guard size.width.isFinite && size.height.isFinite && scale > 0 && scale.isFinite else {
                print("[UIImageExtensions] compositedWithBackground: Invalid size or scale, returning original image")
                return self
            }
            
            // Use opaque context (true) to ensure background color is preserved when converted to JPEG
            // JPEG doesn't support transparency, so opaque ensures the background color is baked in
            UIGraphicsBeginImageContextWithOptions(size, true, scale)
            defer { UIGraphicsEndImageContext() }
            
            guard let context = UIGraphicsGetCurrentContext() else {
                print("[UIImageExtensions] compositedWithBackground: Failed to get graphics context, returning original image")
                return self
            }
            
            // Fill the ENTIRE square with background color (not just a circle)
            // This ensures no white corners when converted to JPEG format
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            // Scale the image to fill the entire canvas (aspect fill) to avoid any border
            // Calculate scale factor to fill the entire square
            let scaleX = size.width / originalSize.width
            let scaleY = size.height / originalSize.height
            let scaleFactor = max(scaleX, scaleY) // Use max to ensure image fills entire canvas
            
            // Calculate scaled size
            let scaledWidth = originalSize.width * scaleFactor
            let scaledHeight = originalSize.height * scaleFactor
            
            // Center the scaled image
            let imageX = (size.width - scaledWidth) / 2.0
            let imageY = (size.height - scaledHeight) / 2.0
            let imageRect = CGRect(
                origin: CGPoint(x: imageX, y: imageY),
                size: CGSize(width: scaledWidth, height: scaledHeight)
            )
            
            // Draw the image scaled to fill the entire canvas - no border visible
            // Use safe drawing with bounds checking
            guard imageRect.width > 0 && imageRect.height > 0,
                  imageRect.width.isFinite && imageRect.height.isFinite,
                  imageRect.origin.x.isFinite && imageRect.origin.y.isFinite,
                  imageRect.maxX <= size.width && imageRect.maxY <= size.height,
                  imageRect.origin.x >= 0 && imageRect.origin.y >= 0 else {
                print("[UIImageExtensions] compositedWithBackground: Invalid image rect (\(imageRect)), returning original")
                return self
            }
            
            // Use the captured CGImage directly for safer drawing
            // Create UIImage from captured cgImage to ensure we're using valid data
            let imageToDraw = UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
            imageToDraw.draw(in: imageRect, blendMode: .normal, alpha: 1.0)
            
            print("[UIImageExtensions] compositedWithBackground: ✅ Composited image with background color \(backgroundColorHex), size=\(size.width)x\(size.height)")
            
            // Get the composited image
            guard let compositedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                print("[UIImageExtensions] compositedWithBackground: Failed to create composited image, returning original")
                return self
            }
            
            return compositedImage
        }
    }
}

