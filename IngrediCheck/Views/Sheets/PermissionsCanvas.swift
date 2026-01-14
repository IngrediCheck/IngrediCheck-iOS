import SwiftUI
import AVFoundation
import UserNotifications
import UIKit

struct PermissionsCanvas: View {
    @Environment(AuthController.self) private var authController
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var cameraEnabled: Bool = false
    @State private var notificationsEnabled: Bool = false
    @State private var showCameraPermissionAlert: Bool = false
    @State private var showNotificationsPermissionAlert: Bool = false

    private var isSignedIn: Bool {
        authController.session != nil && !authController.signedInAsGuest
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Why we need these permissions")
                    .font(ManropeFont.bold.size(16))
                    .foregroundStyle(.grayScale150)
                    .padding(.top,20)

                Text("They help us scan products accurately and\nimprove your experience.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                 
            }
            .padding(.horizontal, 24)

            VStack(spacing: 18) {
                permissionRow(
                    icon: "camera-image",
                    title: "Camera",
                    subtitle: "Used only to scan barcodes and product photos.",
                    isOn: Binding(
                        get: { cameraEnabled },
                        set: { newValue in
                            handleCameraToggleChanged(to: newValue)
                        }
                    ),
                    isLocked: cameraEnabled
                )

                permissionRow(
                    icon: "bell-on-image",
                    title: "Notifications",
                    subtitle: "Get alerts for scan results, tips and product updates.",
                    isOn: Binding(
                        get: { notificationsEnabled },
                        set: { newValue in
                            handleNotificationsToggleChanged(to: newValue)
                        }
                    ),
                    isLocked: notificationsEnabled
                )

                permissionRow(
                    icon: "lock-image",
                    title: "Login Google or Apple account",
                    subtitle: "Save your scans and preferences securely across devices.",
                    isOn: Binding(
                        get: { isSignedIn },
                        set: { newValue in
                            guard newValue, !isSignedIn else { return }
                            coordinator.navigateInBottomSheet(.loginToContinue)
                        }
                    )
                )
            }
       
            .padding(.top, 34)
            .padding(.horizontal, 21)
        

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .task {
            refreshPermissionStates()
        }
        .alert("Camera Permission", isPresented: $showCameraPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to scan products.")
        }
        .alert("Notifications Permission", isPresented: $showNotificationsPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow notifications in Settings to receive updates.")
        }
    }

    private func refreshPermissionStates() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraEnabled = (cameraStatus == .authorized)

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = (settings.authorizationStatus == .authorized)
            }
        }
    }

    private func handleCameraToggleChanged(to newValue: Bool) {
        if newValue == false {
            if cameraEnabled {
                cameraEnabled = true
            } else {
                cameraEnabled = false
            }
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraEnabled = true
        case .notDetermined:
            requestCameraAccess { granted in
                cameraEnabled = granted
                if !granted {
                    showCameraPermissionAlert = true
                }
            }
        case .denied, .restricted:
            cameraEnabled = false
            showCameraPermissionAlert = true
        @unknown default:
            cameraEnabled = false
        }
    }

    private func handleNotificationsToggleChanged(to newValue: Bool) {
        if newValue == false {
            if notificationsEnabled {
                notificationsEnabled = true
            } else {
                notificationsEnabled = false
            }
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                DispatchQueue.main.async {
                    notificationsEnabled = true
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        notificationsEnabled = granted
                        if !granted {
                            showNotificationsPermissionAlert = true
                        }
                    }
                }
            case .denied, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    notificationsEnabled = false
                    showNotificationsPermissionAlert = true
                }
            @unknown default:
                DispatchQueue.main.async {
                    notificationsEnabled = false
                }
            }
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isLocked: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Image(icon)
                .frame(width: 30 ,height: 30)
                .padding(.trailing ,12)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(NunitoFont.bold.size(16))
                    .foregroundStyle(.grayScale150)
                    .lineLimit(1)

                Text(subtitle)
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)                    .fixedSize(horizontal: false, vertical: true)
            }
            
            

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(hex: "#91B640"))
                .allowsHitTesting(!isLocked)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PermissionsCanvas()
        .environment(AuthController())
        .environment(AppNavigationCoordinator())
}
