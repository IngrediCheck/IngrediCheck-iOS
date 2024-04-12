import SwiftUI

struct ProductImagesView: View {

    let images: [DTO.ImageLocationInfo]
    let onPhotoUpload: () -> Void

    @Environment(AppState.self) var appState

    @State private var currentTabViewIndex = 0

    var body: some View {
        VStack(spacing: 15) {
            if images.count != 0 {
                TabView(selection: $currentTabViewIndex.animation()) {
                    ForEach(0 ... images.count, id:\.self) { index in
                        if index == images.count {
                            uploadPhotoButton
                        } else {
                            HeaderImage(imageLocation: images[index])
                                .frame(width: UIScreen.main.bounds.width - 110)
                        }
                    }
                }
                .background(.paletteBackground)
                .frame(height: (UIScreen.main.bounds.width - 110) * (4/3))
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                Fancy3DotsIndexView(numberOfPages: images.count + 1, currentIndex: currentTabViewIndex)
            } else {
                uploadPhotoButton
            }
        }
    }
    
    @MainActor var uploadPhotoButton: some View {
        Button(action: {
            onPhotoUpload()
        }, label: {
            VStack {
                Image(systemName: "photo.badge.plus")
                    .font(.largeTitle)
                    .padding()
                Text("Upload photos")
                    .foregroundStyle(.primary100)
                    .font(.headline)
            }
            .frame(width: UIScreen.main.bounds.width / 2)
            .frame(height: UIScreen.main.bounds.width / 2)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.primary50)
            }
        })
    }
}
