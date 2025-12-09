import SwiftUI
import UIKit

@MainActor
final class MemojiViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var backgroundColorHex: String?
    @Published var isGenerating: Bool = false
    
    func generate(selection: MemojiSelection, coordinator: AppNavigationCoordinator) {
        Task {
            await MainActor.run {
                isGenerating = true
                image = nil
                backgroundColorHex = selection.backgroundHex
                coordinator.navigateInBottomSheet(.bringingYourAvatar)
            }
            do {
                let generated = try await generateMemojiImage(requestBody: selection.toMemojiRequest())
                await MainActor.run {
                    image = generated
                    isGenerating = false
                    coordinator.navigateInBottomSheet(.meetYourAvatar)
                }
            } catch {
                await MainActor.run {
                    image = UIImage(named: "ingrediBot")
                    isGenerating = false
                    coordinator.navigateInBottomSheet(.meetYourAvatar)
                }
            }
        }
    }
}

