import SwiftUI

struct ManageFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var coordinator

    private var familyName: String {
        if let family = familyStore.family {
            return "\(family.selfMember.name)’s Family"
        } else if let pending = familyStore.pendingSelfMember {
            return "\(pending.name)’s Family"
        } else {
            return "Your Family"
        }
    }

    private var members: [FamilyMember] {
        if let family = familyStore.family {
            return [family.selfMember] + family.otherMembers
        }
        var result: [FamilyMember] = []
        if let me = familyStore.pendingSelfMember { result.append(me) }
        result.append(contentsOf: familyStore.pendingOtherMembers)
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    familyCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(hex: "#F7F7F7"))
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if familyStore.family == nil {
                await familyStore.loadCurrentFamily()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.grayScale150)
            }
            Text("Manage Family")
                .font(NunitoFont.bold.size(18))
                .foregroundStyle(.grayScale150)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var familyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(familyName)
                        .font(NunitoFont.semiBold.size(20))
                        .foregroundStyle(.grayScale150)
                    Text("Everyone stays connected and updated here.")
                        .font(ManropeFont.regular.size(12))
                        .foregroundStyle(.grayScale110)
                }
                Spacer()
                Button { } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Edit")
                            .font(ManropeFont.semiBold.size(12))
                    }
                    .foregroundStyle(.grayScale100)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#F2F2F2"), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                ForEach(Array(members.prefix(6)), id: \.id) { member in
                    if let imageName = member.imageFileHash, !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(lineWidth: 1)
                                    .foregroundStyle(Color.white)
                            )
                    } else {
                        Circle()
                            .fill(Color(hex: member.color))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(member.name.prefix(1)))
                                    .font(NunitoFont.semiBold.size(14))
                                    .foregroundStyle(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(lineWidth: 1)
                                    .foregroundStyle(Color.white)
                            )
                    }
                }
                Spacer()
                Button {
                    coordinator.navigateInBottomSheet(.addMoreMembers)
                } label: {
                    GreenCapsule(title: "+ Add Member")
                        .frame(width: 164)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.75)
                .foregroundStyle(Color(hex: "#EEEEEE"))
        )
        .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
    }
}

#Preview {
    ManageFamilyView()
        .environment(FamilyStore())
}
