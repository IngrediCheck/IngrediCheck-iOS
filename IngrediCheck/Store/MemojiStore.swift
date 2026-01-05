import SwiftUI
import Observation
import UIKit

@Observable
@MainActor
final class MemojiStore {
    var image: UIImage?
    /// Storage path inside the `memoji-images` bucket for the last generated memoji.
    /// Example: `2025/01/<hash>.png`. Used as `imageFileHash` when assigning avatars
    /// so we can load directly from Supabase without re-uploading the PNG.
    var imageStoragePath: String?
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
    
    deinit {
        print("[MemojiStore] ❌ MemojiStore deallocated")
    }
    
    func generate(selection: MemojiSelection, coordinator: AppNavigationCoordinator) async {
        print("[MemojiStore] ═══════════════════════════════════════════════════")
        print("[MemojiStore] generate() called - Thread.isMainThread=\(Thread.isMainThread)")
        isGenerating = true
        image = nil
        imageStoragePath = nil
        print("[MemojiStore] image set to nil, backgroundColorHex=\(selection.backgroundHex ?? "nil")")
        backgroundColorHex = selection.backgroundHex
        coordinator.navigateInBottomSheet(.bringingYourAvatar)
        print("[MemojiStore] Navigated to .bringingYourAvatar")
        
        do {
            print("[MemojiStore] Calling generateMemojiImage...")
            let generated = try await generateMemojiImage(requestBody: selection.toMemojiRequest())
            
            // CRITICAL: Check for cancellation before updating state
            guard !Task.isCancelled else {
                print("[MemojiStore] ⚠️ Task cancelled before assigning image")
                isGenerating = false
                return
            }
            
            print("[MemojiStore] generateMemojiImage returned - Thread.isMainThread=\(Thread.isMainThread)")
            
            // Check for cancellation before processing
            guard !Task.isCancelled else {
                print("[MemojiStore] ⚠️ Task cancelled before image assignment")
                isGenerating = false
                return
            }
            
            // CRITICAL: Assign image and storage path first to ensure they're properly stored
            // before any access. Assignment is on main thread since MemojiStore is @MainActor.
            image = generated.image
            imageStoragePath = generated.storagePath
            print("[MemojiStore] ✅ image assigned to memojiStore.image - Thread.isMainThread=\(Thread.isMainThread)")
            
            // Access size for logging only, wrapped in MainActor.run for thread safety
            // This ensures UIImage internal state is accessed on main thread
            let (width, height) = await MainActor.run {
                let w = generated.image.size.width
                let h = generated.image.size.height
                print("[MemojiStore] image.size - width=\(w), height=\(h), Thread.isMainThread=\(Thread.isMainThread)")
                return (w, h)
            }
            
            // Check again before navigation
            guard !Task.isCancelled else {
                print("[MemojiStore] ⚠️ Task cancelled before navigation")
                isGenerating = false
                return
            }
            
            // Ensure one render cycle completes before navigation to prevent transition crashes
            // This gives SwiftUI time to properly commit the image assignment
            try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame at 60fps
            
            guard !Task.isCancelled else {
                print("[MemojiStore] ⚠️ Task cancelled during navigation delay")
                isGenerating = false
                return
            }
            
            print("[MemojiStore] About to navigate to .meetYourAvatar")
            coordinator.navigateInBottomSheet(.meetYourAvatar)
            print("[MemojiStore] ✅ Navigated to .meetYourAvatar")
        } catch {
            // Log error so we can debug why memoji generation failed
            print("[MemojiStore] ❌ Memoji generation failed: \(error.localizedDescription)")
            print("[MemojiStore] ❌ Error debugging info: \(error)")
            
            // Check for cancellation before updating state
            guard !Task.isCancelled else {
                print("[MemojiStore] ⚠️ Task cancelled during error handling")
                isGenerating = false
                return
            }
            
            // UIImage(named:) is safe - already on main thread due to @MainActor
            let fallbackImage = UIImage(named: "ingrediBot")
            print("[MemojiStore] Fallback image created - image=\(fallbackImage != nil ? "exists" : "nil"), Thread.isMainThread=\(Thread.isMainThread)")
            image = fallbackImage
            print("[MemojiStore] Fallback image assigned to memojiStore.image")
            
            guard !Task.isCancelled else {
                print("[MemojiStore] ⚠️ Task cancelled before fallback navigation")
                isGenerating = false
                return
            }
            
            coordinator.navigateInBottomSheet(.meetYourAvatar)
            print("[MemojiStore] Navigated to .meetYourAvatar (with fallback)")
        }
        
        // Final cancellation check before clearing the generating flag
        guard !Task.isCancelled else {
            print("[MemojiStore] ⚠️ Task cancelled before clearing isGenerating")
            return
        }
        
        isGenerating = false
        print("[MemojiStore] generate() completed - isGenerating=false")
        print("[MemojiStore] ═══════════════════════════════════════════════════")
    }
}

