import SwiftUI

struct PermissionsCanvas: View {
    @Environment(AuthController.self) private var authController
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var cameraEnabled: Bool = true
    @State private var notificationsEnabled: Bool = true

    private var isSignedIn: Bool {
        authController.session != nil && !authController.signedInAsGuest
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Why we need these permissions")
                    .font(ManropeFont.bold.size(16))
                    .foregroundStyle(.grayScale150)
                    .padding(.top, 44)

                Text("They help us scan products accurately and\nimprove your experience.")
                    .font(ManropeFont.regular.size(13))
                    .foregroundStyle(Color(hex: "#BDBDBD"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 18) {
                permissionRow(
                    icon: "camera",
                    title: "Camera",
                    subtitle: "Used only to scan barcodes and product photos.",
                    isOn: $cameraEnabled
                )

                permissionRow(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: "Get alerts for scan results, tips and product updates.",
                    isOn: $notificationsEnabled
                )

                permissionRow(
                    icon: "lock",
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
            .padding(.top, 28)
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func permissionRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "#91B640"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ManropeFont.bold.size(14))
                    .foregroundStyle(.grayScale150)

                Text(subtitle)
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(Color(hex: "#BDBDBD"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(hex: "#91B640"))
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PermissionsCanvas()
}
