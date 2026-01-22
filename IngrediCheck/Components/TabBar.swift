//
//  TabBar.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 09/10/25.
//

import SwiftUI
import AVFoundation

struct TabBar: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator

    @State var scale: CGFloat = 1.0
    @State var offsetY: CGFloat = 0
    @Binding var isExpanded: Bool
    @State private var isCameraPresented = false
    @State private var showCameraPermissionAlert = false
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    @Environment(AppState.self) var appState
    var onRecentScansTap: (() -> Void)? = nil
    var onChatBotTap: (() -> Void)? = nil


    var body: some View {
//        ZStack {
            ZStack(alignment: .bottom) {
                HStack(alignment: .center) {
                    Button {
                        onRecentScansTap?()
                    } label: {
                        Image("tabBar-history")
                            .renderingMode(.template)
                            .resizable()
                            .foregroundColor(Color(hex: "676A64"))
                            .frame(width: 26, height: 26)
                    }
                   
                    
                    Spacer()
                    
                    Button {
                        if let onChatBotTap {
                            onChatBotTap()
                        } else {
                            coordinator.presentChatBot(startAtConversation: true)
                        }
                    } label: {
                        Image("tabBar-ingredibot")
                            .renderingMode(.template)
                            .resizable()
                            .foregroundColor(Color(hex: "676A64"))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12.5)
                .frame(width: 196)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: Color(hex: "E9E9E9"), radius: 13.6, x: 0, y: 12)
                )
                .overlay(
                    Capsule()
                        .stroke(lineWidth: 0.25)
                        .foregroundStyle(.grayScale50)
                )
                .scaleEffect(scale)
                .offset(y: offsetY)
                
                Button {
                    handleScannerTap()
                } label: {
                    ZStack {
                        Circle()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color(hex: "91C206"), location: 0.2),
                                        .init(color: Color(hex: "6B8E06"), location: 0.7)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                    .shadow(
                                        .inner(color: Color(hex: "99C712"), radius: 2.5, x: 4, y: -2.5)
                                    )
                                    .shadow(
                                        .drop(color: Color(hex: "606060").opacity(0.35), radius: 3.3, x: 0, y: 4)
                                    )
                            )
                            .rotationEffect(.degrees(18))

                        Image("tabBar-scanner")
                            .resizable()
                            .frame(width: 32, height: 32)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }
            .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
                Button("Later", role: .cancel) { }
                Button("Open Settings") {
                    openAppSettings()
                }
            } message: {
                Text("To scan products, please allow camera access in Settings.")
            }
            .onChange(of: isExpanded) { oldValue, newValue in
                something()
            }
            .fullScreenCover(isPresented: $isCameraPresented, onDismiss: {
                Task {
                    // Refresh scan history from backend
                    await scanHistoryStore.loadHistory(forceRefresh: true)
                    // Sync to AppState for UI display in HomeView
                    await MainActor.run {
                        appState.listsTabState.scans = scanHistoryStore.scans
                    }
                }
            }) {
                ScanCameraView()
            }
            
    }
    
    
    // MARK: - Camera Permission Handling

    private func handleScannerTap() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            // Permission already granted, open camera
            isCameraPresented = true

        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        isCameraPresented = true
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }

        case .denied, .restricted:
            // Permission denied or restricted, show alert
            showCameraPermissionAlert = true

        @unknown default:
            showCameraPermissionAlert = true
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: - Tab Bar Animation

    func something() {
        withAnimation(.smooth) {

            if isExpanded {
                withAnimation(.smooth) {
                    offsetY = 25
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.smooth) {
                        scale = 1
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.smooth) {
                        offsetY = 0
                    }
                }

            } else {
                withAnimation(.smooth) {
                    offsetY = 25
                }


                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.smooth) {
                        scale = 0.1
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.smooth) {
                        offsetY = 0
                    }
                }
            }

        }

    }

}

#Preview {
    VStack {
        Image("Iphone-image")
            .resizable()
//            .aspectRatio(contentMode: .fill)
            .opacity(0.1).ignoresSafeArea()
        TabBar(isExpanded: .constant(true))
            .environment(AppState())
            .environment(ScanHistoryStore(webService: WebService()))
            .environment(AppNavigationCoordinator(initialRoute: .home))
    }
}
