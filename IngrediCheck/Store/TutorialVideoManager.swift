import Foundation

final class TutorialVideoManager {

    static let shared = TutorialVideoManager()

    private let bucket = "assets-client"
    private let fileName = "app-tutorial.mov"
    private var isDownloading = false

    private init() {}

    var videoFileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent(fileName)
    }

    var isVideoAvailable: Bool {
        FileManager.default.fileExists(atPath: videoFileURL.path)
    }

    func downloadIfNeeded() async {
        guard !isVideoAvailable, !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }

        do {
            let data = try await supabaseClient.storage
                .from(bucket)
                .download(path: fileName)
            try data.write(to: videoFileURL, options: Data.WritingOptions.atomic)
            Log.debug("TutorialVideoManager", "Downloaded tutorial video (\(data.count) bytes)")
        } catch {
            Log.error("TutorialVideoManager", "Failed to download tutorial video: \(error)")
        }
    }

    func removeVideo() {
        guard isVideoAvailable else { return }
        do {
            try FileManager.default.removeItem(at: videoFileURL)
            Log.debug("TutorialVideoManager", "Removed tutorial video from documents")
        } catch {
            Log.error("TutorialVideoManager", "Failed to remove tutorial video: \(error)")
        }
    }
}
