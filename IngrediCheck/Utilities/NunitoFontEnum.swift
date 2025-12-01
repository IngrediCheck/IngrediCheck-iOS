//
//  NunitoFontEnum.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 08/10/25.
//

import Foundation
import SwiftUI

enum NunitoFont: String {
    case extraLight = "Nunito-ExtraLight"
    case light = "Nunito-Light"
    case regular = "Nunito-Regular"
    case medium = "Nunito-Medium"
    case semiBold = "Nunito-SemiBold"
    case bold = "Nunito-Bold"
    case extraBold = "Nunito-ExtraBold"
    case black = "Nunito-Black"
    
    case extraLightItalic = "Nunito-ExtraLightItalic"
    case lightItalic = "Nunito-LightItalic"
    case italic = "Nunito-Italic"
    case mediumItalic = "Nunito-MediumItalic"
    case semiBoldItalic = "Nunito-SemiBoldItalic"
    case boldItalic = "Nunito-BoldItalic"
    case extraBoldItalic = "Nunito-ExtraBoldItalic"
    case blackItalic = "Nunito-BlackItalic"
    
    var fontName: String { rawValue }
    
    func size(_ size: CGFloat) -> Font {
        return .custom(self.fontName, size: size)
    }
}
