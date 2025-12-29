import SwiftUI
import Observation
import UIKit

@Observable
@MainActor
final class MemojiStore {
    var image: UIImage?
    var backgroundColorHex: String?
    var isGenerating = false
    
    // Display context for UI (e.g., show typed name in Generate Avatar header)
    var displayName: String? = nil
    
    // Track where GenerateAvatar was navigated from for back button navigation
    var previousRouteForGenerateAvatar: BottomSheetRoute? = nil
    
    // Store avatar generation selections to preserve state when navigating back
    var selectedFamilyMemberName: String = "young-son"
    var selectedFamilyMemberImage: String = "image-bg1"
    var selectedTool: String = "family-member"
    var selectedGestureIcon: String? = nil
    var selectedHairStyleIcon: String? = nil
    var selectedSkinToneIcon: String? = nil
    var selectedAccessoriesIcon: String? = nil
    var selectedColorThemeIcon: String? = nil
    var currentToolIndex: Int = 0
    
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
            // Log error so we can debug why memoji generation failed
            print("Memoji generation failed: \(error.localizedDescription)")
            image = UIImage(named: "ingrediBot")
            coordinator.navigateInBottomSheet(.meetYourAvatar)
        }
        
        isGenerating = false
    }
}

