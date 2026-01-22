import SwiftUI

/// Flash toggle button for scanner and photo modes
struct FlashToggleButton: View {
    @State private var isFlashon = false
    /// When `true`, show the system torch icon; when `false`, show the custom flash asset.
    var isScannerMode: Bool
    /// Optional callback used in photo mode so the parent can decide what to do
    /// with the armed flash state when a picture is taken.
    var onTogglePhotoFlash: ((Bool) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if isScannerMode {
                // Scanner mode: show torch icon only (no background, matches nav back button)
                Image(systemName: isFlashon ? "flashlight.on.fill" : "flashlight.off.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.white)
            } else {
                // Photo mode: show custom flash asset
                ZStack {
                    Circle()
                        .fill(.bar.opacity(0.4))
                        .frame(width: 48, height: 48)
                    Image(isFlashon ? "flashon" : "flashoff")
                        .resizable()
                        .frame(width: 28, height: 24)
                        .foregroundColor(.white)
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut) {
                if isScannerMode {
                    // In live scanner mode, toggle the device torch immediately.
                    FlashManager.shared.toggleFlash { on in
                        self.isFlashon = on
                    }
                } else {
                    // In photo capture mode, only arm/disarm flash for the next shot.
                    isFlashon.toggle()
                    onTogglePhotoFlash?(isFlashon)
                }
            }
        }
        .onAppear {
            // Keep UI in sync with the current hardware state for scanner mode.
            if isScannerMode {
                isFlashon = FlashManager.shared.isFlashOn()
            }
        }
    }
}
