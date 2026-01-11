import SwiftUI

struct ManageFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(WebService.self) private var webService
    @State private var selfMemberName: String = ""
    @FocusState private var isEditingFamilyName: Bool
    @State private var nameFieldWidth: CGFloat = 0

    private struct NameWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
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
    
    private var extraMemberCount: Int {
        let maxShown = 6
        return max(members.count - maxShown, 0)
    }

    // Keep type-checking simple by pulling complex width math out of the view modifiers
    private var nameFieldEffectiveWidth: CGFloat {
        let measured = (nameFieldWidth == 0 ? 300 : nameFieldWidth)
        return min(max(measured, 144), 300)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                Section {
                    familyCard
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(members) { member in
                        MemberRow(member: member)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                let isSelfRow: Bool = {
                                    if let family = familyStore.family {
                                        return member.id == family.selfMember.id
                                    }
                                    return member.id == familyStore.pendingSelfMember?.id
                                }()
                             
                                    if !isSelfRow {
                                        Button {
                                            Task {
                                                if familyStore.family != nil {
                                                    await familyStore.deleteMember(id: member.id)
                                                } else {
                                                    familyStore.removePendingOtherMember(id: member.id)
                                                }
                                            }
                                        } label: {
                                            VStack(spacing: 4) {
                                                Image("Delete-icon")
                                                    .resizable()
                                                    .frame(width: 14, height: 14)
                                                Text("Remove")
                                                    .font(NunitoFont.regular.size(8))
                                                    .foregroundStyle(Color(hex: "#F04438"))
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 24)
                                                    .fill(Color(hex: "#F7F7F7"))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 24)
                                                    .stroke(Color(hex: "#F7F7F7"), lineWidth: 0.75)
                                            )
                                        }
                                        .tint(Color(hex: "#F7F7F7"))
                                    }
                               
                            }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await familyStore.loadCurrentFamily()
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#F7F7F7"))
        }
        .background(Color(hex: "#F7F7F7"))
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selfMemberName = familyStore.family?.selfMember.name
            ?? familyStore.pendingSelfMember?.name
            ?? ""
        }
        .onChange(of: (familyStore.family?.selfMember.name ?? familyStore.pendingSelfMember?.name ?? "")) { _, newValue in
            guard !newValue.isEmpty, !isEditingFamilyName else { return }
            if selfMemberName != newValue { selfMemberName = newValue }
        }
        .onChange(of: selfMemberName) { oldValue, newValue in
            // Filter to letters and spaces only
            let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
            var finalized = filtered
            
            // Limit to 25 characters
            if finalized.count > 25 {
                finalized = String(finalized.prefix(25))
            }
            
            // Limit to max 3 words (max 2 spaces)
            let components = finalized.components(separatedBy: .whitespaces)
            if components.count > 3 {
                finalized = components.prefix(3).joined(separator: " ")
            }
            
            if finalized != newValue {
                selfMemberName = finalized
            }
        }
        .task {
            if familyStore.family == nil {
                await familyStore.loadCurrentFamily()
            }
        }
    }

    private func commitSelfName() {
        let trimmed = selfMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            if let family = familyStore.family {
                var me = family.selfMember
                guard me.name != trimmed else { return }
                me.name = trimmed
                await familyStore.editMember(me)
            } else if familyStore.pendingSelfMember != nil {
                if familyStore.pendingSelfMember?.name != trimmed {
                    familyStore.updatePendingSelfMemberName(trimmed)
                }
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
                    HStack(spacing: 4) {
                        TextField("", text: $selfMemberName)
                            .font(NunitoFont.semiBold.size(20))
                            .foregroundStyle(.grayScale150)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($isEditingFamilyName)
                            .submitLabel(.done)
                            .onSubmit { commitSelfName() }
                            .onChange(of: isEditingFamilyName) { _, editing in
                                if !editing { commitSelfName() }
                            }
                            .frame(width: nameFieldEffectiveWidth)
                            .overlay(alignment: .leading) {
                                Text(selfMemberName.isEmpty ? " " : selfMemberName)
                                    .font(NunitoFont.semiBold.size(20))
                                    .background(
                                        GeometryReader { proxy in
                                            Color.clear.preference(key: NameWidthPreferenceKey.self, value: min(proxy.size.width, 300))
                                        }
                                    )
                                    .hidden()
                            }
                        Button { isEditingFamilyName = true } label: {
                            Image("pen-line")
                                .resizable()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(.grayScale100)
                        }
                        .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .onTapGesture { isEditingFamilyName = true }
                    }
                    .padding(.horizontal, 4)
                    .onPreferenceChange(NameWidthPreferenceKey.self) { width in
                        if nameFieldWidth != width { nameFieldWidth = width }
                    }
                        Text("Everyone stays connected and updated here.")
                            .font(ManropeFont.regular.size(12))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 161, alignment: .leading)
                            .foregroundStyle(.grayScale110)
                    
                }
                
            }

            HStack(spacing: -8) {
                ForEach(Array(members.prefix(6)), id: \.id) { member in
                    MemberAvatar.custom(member: member, size: 32, imagePadding: 0)
                }
                if extraMemberCount > 0 {
                    Circle()
                        .fill(Color(hex: "#F2F2F2"))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("+\(extraMemberCount)")
                                .font(NunitoFont.semiBold.size(12))
                                .foregroundStyle(.grayScale130)
                        )
                        .overlay(
                            Circle()
                                .stroke(lineWidth: 1)
                                .foregroundStyle(Color.white)
                        )
                }
                Spacer()
                Button {
                    coordinator.navigateInBottomSheet(.addMoreMembers)
                } label: {
                    GreenCapsule(title: "Add Member", width: 110, height: 36, takeFullWidth: false, labelFont: NunitoFont.semiBold.size(12))
                        .frame(width: 110, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
     
      
        .padding(20)
        .frame(height: 143)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(lineWidth: 0.75)
                .foregroundStyle(Color(hex: "#EEEEEE"))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10.1, x: 0, y: 2)
        .padding(20)
        
        
    }

    struct MemberRow: View {
        let member: FamilyMember
        @Environment(FamilyStore.self) private var familyStore
        @Environment(AppNavigationCoordinator.self) private var coordinator
        @State private var showLeaveConfirm = false

        private var isSelf: Bool {
            if let family = familyStore.family {
                return member.id == family.selfMember.id
            }
            return member.id == familyStore.pendingSelfMember?.id
        }

        var body: some View {
            HStack(spacing: 12) {
                // Info Section: Avatar + Name + Status (Tapping this triggers Edit)
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        SmartMemberAvatar(member: member)
                            .frame(width: 48, height: 48)
                        
                        Circle()
                            .fill(.grayScale40)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image("pen-line")
                                    .resizable()
                                    .frame(width: 7.43, height: 7.43)
                            )
                            .offset(x: -4, y: 4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(NunitoFont.semiBold.size(18))
                            .foregroundStyle(.grayScale150)
                        
                        statusView
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    print("[ManageFamilyView] Info area tapped for \(member.name), navigating to edit")
                    coordinator.navigateInBottomSheet(.editMember(memberId: member.id, isSelf: isSelf))
                }

                // Action Area: Invite or Leave (Independent tap target)
                actionButton
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(lineWidth: 0.75)
                    .foregroundStyle(Color(hex: "#EEEEEE"))
            )
        }

        @ViewBuilder
        private var statusView: some View {
            if isSelf {
                Text("(You)")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale110)
            } else if member.joined {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#4CAF50"))
                    Text("Joined")
                        .font(ManropeFont.semiBold.size(10))
                        .foregroundStyle(Color(hex: "#4CAF50"))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(hex: "#EAF6ED"), in: Capsule())
            } else if member.invitePending == true {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#F4A100"))
                    Text("Pending")
                        .font(ManropeFont.semiBold.size(10))
                        .foregroundStyle(Color(hex: "#F4A100"))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(hex: "#FFF7E6"), in: Capsule())
            } else {
                Text("Not joined yet !")
                    .font(NunitoFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
            }
        }

        @ViewBuilder
        private var actionButton: some View {
            if isSelf {
                Button {
                    showLeaveConfirm = true
                } label: {
                    Text("Leave Family")
                        .font(NunitoFont.semiBold.size(12))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(hex: "#F2F2F2"), in: Capsule())
                }
                .buttonStyle(.plain)
                .confirmationDialog("Leave Family", isPresented: $showLeaveConfirm) {
                    Button("Leave Family", role: .destructive) {
                        Task { await familyStore.leave() }
                    }
                } message: {
                    Text("Are you sure you want to leave?")
                }
            } else {
                Button {
                    print("[ManageFamilyView] Invite button tapped for \(member.name)")
                    coordinator.navigateInBottomSheet(.wouldYouLikeToInvite(memberId: member.id, name: member.name))
                } label: {
                    HStack(spacing: 6) {
                        Image("share")
                            .resizable()
                            .frame(width: 14, height: 14)
                        Text(member.joined ? "Re-invite" : "Invite")
                            .font(NunitoFont.semiBold.size(12))
                    }
                    .foregroundStyle(Color(hex: "#91B640"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color(hex: "#91B640"), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private struct SmartMemberAvatar: View {
        let member: FamilyMember
        
        var body: some View {
            // Use centralized MemberAvatar component with stroke overlay
            ZStack {
                MemberAvatar.medium(member: member)
                
                // Additional stroke overlay for this specific view
                Circle()
                    .stroke(Color.grayScale40, lineWidth: 2)
                    .frame(width: 48, height: 48)
            }
        }
    }
}

#Preview {
    ManageFamilyView()
        .environment(FamilyStore())
}
