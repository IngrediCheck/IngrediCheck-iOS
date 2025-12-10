import SwiftUI
import Observation
import UIKit

@Observable
@MainActor
final class MemojiStore {
    var image: UIImage?
    var backgroundColorHex: String?
    var isGenerating = false
    
    func generate(selection: MemojiSelection, coordinator: AppNavigationCoordinator) async {
        isGenerating = true
        image = nil
        backgroundColorHex = selection.backgroundHex
        coordinator.navigateInBottomSheet(.bringingYourAvatar)
        
        do {
            let generated = try await generateMemojiImage(requestBody: selection.toMemojiRequest())
            image = generated
            coordinator.navigateInBottomSheet(.meetYourAvatar)
        } catch {
            image = UIImage(named: "ingrediBot")
            coordinator.navigateInBottomSheet(.meetYourAvatar)
        }
        
        isGenerating = false
    }
}

