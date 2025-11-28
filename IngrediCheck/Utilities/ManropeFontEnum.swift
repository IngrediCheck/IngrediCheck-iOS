//
//  ManropeFontEnum.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import Foundation
import SwiftUI

enum ManropeFont: String {
    case extraLight = "Manrope-ExtraLight"
    case light = "Manrope-Light"
    case regular = "Manrope-Regular"
    case medium = "Manrope-Medium"
    case semiBold = "Manrope-SemiBold"
    case bold = "Manrope-Bold"
    case extraBold = "Manrope-ExtraBold"
    
    var fontName: String { rawValue }
    
    func size(_ size: CGFloat) -> Font {
        return .custom(self.fontName, size: size)
    }
}
