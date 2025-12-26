//
//  UIImageExtensions.swift
//  IngrediCheck
//
//  Created on 13/12/25.
//

import UIKit

extension UIImage {
    /// Composites the image with a background color, creating a circular image with the background visible behind transparent areas.
    /// - Parameter backgroundColorHex: Hex color string (with or without # prefix)
    /// - Returns: A new UIImage with the background color composited behind the image
    func compositedWithBackground(backgroundColorHex: String) -> UIImage? {
        // Safety check: ensure image has valid dimensions
        let originalSize = self.size
        guard originalSize.width > 0 && originalSize.height > 0 else {
            print("[UIImageExtensions] compositedWithBackground: Invalid image size (\(originalSize.width)x\(originalSize.height)), returning original image")
            return self
        }
        
        // Ensure we work with a square image (use the larger dimension)
        let maxDimension = max(originalSize.width, originalSize.height)
        let size = CGSize(width: maxDimension, height: maxDimension)
        let scale = self.scale
        
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
        
        // Calculate centered position for the image if it's not square
        let imageX = (size.width - originalSize.width) / 2.0
        let imageY = (size.height - originalSize.height) / 2.0
        let imageRect = CGRect(origin: CGPoint(x: imageX, y: imageY), size: originalSize)
        
        // Draw the image on top - transparent areas will show the background color we just filled
        self.draw(in: imageRect, blendMode: .normal, alpha: 1.0)
        
        print("[UIImageExtensions] compositedWithBackground: ✅ Composited image with background color \(backgroundColorHex), size=\(size.width)x\(size.height)")
        
        // Get the composited image
        guard let compositedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("[UIImageExtensions] compositedWithBackground: Failed to create composited image, returning original")
            return self
        }
        
        return compositedImage
    }
}

