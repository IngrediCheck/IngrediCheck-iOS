import SwiftUI
import AVKit
import UIKit

struct ScanningHelpCanvas: View {

    @Environment(NetworkState.self) private var networkState
    @State private var showFullScreen = false
    @State private var isVideoReady = false
    @State private var downloadFailed = false

    private var videoURL: URL {
        TutorialVideoManager.shared.videoFileURL
    }

    private var playerItem: AVPlayerItem? {
        guard isVideoReady else { return nil }
        return AVPlayerItem(url: videoURL)
    }

    var body: some View {
        VStack {

            Image("logo-with-name")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 170, height: 36)
                .padding(.vertical, 24)

            Image("trans_mockup")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 234)
                .overlay {
                    if let playerItem {
                        LoopingVideoPlayer(playerItem: playerItem)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 8)
                    } else if !networkState.connected || downloadFailed {
                        // Offline state with retry
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.grayScale90)

                            Text("No internet connection")
                                .font(ManropeFont.medium.size(14))
                                .foregroundStyle(.grayScale120)

                            Button {
                                downloadFailed = false
                                Task {
                                    await TutorialVideoManager.shared.downloadIfNeeded()
                                    isVideoReady = TutorialVideoManager.shared.isVideoAvailable
                                    if !isVideoReady {
                                        downloadFailed = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(ManropeFont.semiBold.size(14))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.paletteAccent, in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ProgressView()
                            .tint(.grayScale90)
                    }
                }
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        showFullScreen = true
                    } label: {
                        Image("full-screen-icon")
                            .resizable()
                            .frame(width: 26, height: 26)
                            .background(Color.grayScale40)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .padding(.trailing , -32)
                    .padding(.bottom, 8)
                }
                .padding(.bottom, 200)

        }
        .frame(maxWidth: .infinity)
        .background(Color(.pageBackground))
        .task {
            if TutorialVideoManager.shared.isVideoAvailable {
                isVideoReady = true
            } else {
                await TutorialVideoManager.shared.downloadIfNeeded()
                isVideoReady = TutorialVideoManager.shared.isVideoAvailable
                if !isVideoReady {
                    downloadFailed = true
                }
            }
        }
        .onDisappear {
            TutorialVideoManager.shared.removeVideo()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let playerItem {
                FullScreenVideoPlayer(playerItem: playerItem)
            }
        }
    }
}

struct LoopingVideoPlayer: UIViewRepresentable {

    let playerItem: AVPlayerItem

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(playerItem: playerItem)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

class LoopingPlayerUIView: UIView {

    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(playerItem: AVPlayerItem) {
        super.init(frame: .zero)

        let player = AVQueuePlayer(items: [playerItem])
        player.isMuted = true
        self.player = player
        self.looper = AVPlayerLooper(player: player, templateItem: playerItem)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

struct FullScreenVideoPlayer: View {

    @Environment(\.dismiss) private var dismiss

    let playerItem: AVPlayerItem
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .onAppear {
            let avPlayer = AVPlayer(playerItem: playerItem)
            self.player = avPlayer
            avPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    ScanningHelpCanvas()
}
