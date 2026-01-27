import SwiftUI

// MARK: - Custom Swipeable Row

struct SwipeableDeleteRow<Content: View>: View {
    let content: Content
    let isJoined: Bool
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false

    private let deleteButtonWidth: CGFloat = 88

    init(isJoined: Bool, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isJoined = isJoined
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button behind
            HStack {
                Spacer()
                deleteButton
                    .padding(.trailing, 4)
            }

            // Main content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {
                                // Swiping left
                                offset = max(translation, -deleteButtonWidth)
                            } else if isSwiped {
                                // Swiping right to close
                                offset = min(0, -deleteButtonWidth + translation)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                if value.translation.width < -40 {
                                    // Snap open
                                    offset = -deleteButtonWidth
                                    isSwiped = true
                                } else {
                                    // Snap closed
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
        }
        .clipped()
    }

    private var deleteButton: some View {
        Button {
            if !isJoined {
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = 0
                    isSwiped = false
                }
                onDelete()
            }
        } label: {
            HStack {
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Image("Delete-icon")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(isJoined ? Color(hex: "#BDBDBD") : Color(hex: "#F04438"))
                    Text("Remove")
                        .font(NunitoFont.medium.size(12))
                        .foregroundStyle(isJoined ? Color(hex: "#BDBDBD") : Color(hex: "#F04438"))
                }
                .padding(.trailing)
            }
            .frame(height: 72)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "#F7F7F7"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#E5E5E5"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isJoined)
    }
}

struct ManageFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(WebService.self) private var webService
    @State private var familyName: String = ""
    @FocusState private var isEditingFamilyName: Bool
    @State private var nameFieldWidth: CGFloat = 0
    @State private var shareItems: ShareItem?
    @State private var isGeneratingInviteCode: Bool = false
    
    private let appStoreURL = "https://apps.apple.com/us/app/ingredicheck-grocery-scanner/id6477521615"
    
    struct ShareItem: Identifiable {
        let id = UUID()
        let items: [Any]
    }

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

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    familyCard
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(members) { member in
                        let isSelfRow: Bool = {
                            if let family = familyStore.family {
                                return member.id == family.selfMember.id
                            }
                            return member.id == familyStore.pendingSelfMember?.id
                        }()

                        if isSelfRow {
                            // Self row - no swipe action
                            MemberRow(member: member, onInvite: handleInviteShare)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                                .listRowBackground(Color.clear)
                        } else {
                            // Other members - custom swipe to delete
                            SwipeableDeleteRow(
                                isJoined: member.joined,
                                onDelete: {
                                    Task {
                                        if familyStore.family != nil {
                                            await familyStore.deleteMember(id: member.id)
                                        } else {
                                            familyStore.removePendingOtherMember(id: member.id)
                                        }
                                    }
                                }
                            ) {
                                MemberRow(member: member, onInvite: handleInviteShare)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                            .listRowBackground(Color.clear)
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
            .background(Color.pageBackground)
        }
        .background(Color.pageBackground)
        .navigationTitle("Manage Family")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize family name: use existing family name, or generate from self member's first name
            if let family = familyStore.family {
                familyName = family.name
            } else if let selfMember = familyStore.pendingSelfMember {
                let firstName = selfMember.name.components(separatedBy: " ").first ?? selfMember.name
                familyName = "\(firstName)'s Family"
            } else {
                familyName = ""
            }
        }
        .onChange(of: familyStore.family?.name) { _, newValue in
            guard let newValue = newValue, !newValue.isEmpty, !isEditingFamilyName else { return }
            if familyName != newValue { familyName = newValue }
        }
        .onChange(of: familyName) { oldValue, newValue in
            // Filter to letters, spaces, apostrophes, and hyphens (for names like "O'Brien" or "Mary-Jane")
            let filtered = newValue.filter { $0.isLetter || $0.isWhitespace || $0 == "'" || $0 == "-" }
            var finalized = filtered
            
            // Limit to 50 characters (family names can be longer than individual names)
            if finalized.count > 50 {
                finalized = String(finalized.prefix(50))
            }
            
            if finalized != newValue {
                familyName = finalized
            }
        }
        .task {
            if familyStore.family == nil {
                await familyStore.loadCurrentFamily()
            }
        }
        .sheet(item: $shareItems) { shareItem in
            ShareSheet(activityItems: shareItem.items)
        }
        .onDisappear {
            // Reset flag when leaving family management
            coordinator.isCreatingFamilyFromSettings = false
        }
    }
    
    // MARK: - Invite Share Helper
    
    @MainActor
    private func handleInviteShare(memberId: UUID) async {
        guard !isGeneratingInviteCode else { return }
        
        isGeneratingInviteCode = true
        defer { isGeneratingInviteCode = false }
        
        // Mark member as pending so the UI reflects it
        familyStore.setInvitePendingForPendingOtherMember(id: memberId, pending: true)
        
        // Ensure family exists before creating invite codes
        if familyStore.family == nil {
            if coordinator.isCreatingFamilyFromSettings {
                await familyStore.addPendingMembersToExistingFamily()
            } else {
                await familyStore.createFamilyFromPendingIfNeeded()
            }
        }
        
        guard let code = await familyStore.invite(memberId: memberId) else {
            return
        }
        
        let message = inviteShareMessage(inviteCode: code)
        let items = [message]
        shareItems = ShareItem(items: items)
    }
    
    private func inviteShareMessage(inviteCode: String) -> String {
        let formattedCode = formattedInviteCode(inviteCode)
        return "You've been invited to join my IngrediCheck family.\nSet up your food profile and get personalized ingredient guidance tailored just for you.\n\n📲 Download from the App Store \(appStoreURL) and enter this invite code:\n\(formattedCode)"
    }
    
    private func formattedInviteCode(_ inviteCode: String) -> String {
        let spaced = inviteCode.map { String($0) }.joined(separator: " ")
        return "**\(spaced)**"
    }

    private func commitFamilyName() {
        let trimmed = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            if let family = familyStore.family {
                // Update family name using updateFamily (PATCH request)
                guard family.name != trimmed else { return }
                await familyStore.updateFamily(name: trimmed)
            } else if familyStore.pendingSelfMember != nil {
                // For pending families, just update the local state
                // The family name will be set when the family is created
                // For now, we can't update it until the family is created
                print("[ManageFamilyView] Cannot update family name for pending family")
            }
        }
    }

    @ViewBuilder
    private func familyNameEditField() -> some View {
        HStack(spacing: 12) {
            TextField("", text: $familyName)
                .font(NunitoFont.semiBold.size(22))
                .foregroundStyle(Color(hex: "#303030"))
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($isEditingFamilyName)
                .submitLabel(.done)
                .onSubmit { commitFamilyName() }
            Image("pen-line")
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundStyle(.grayScale100)
                .onTapGesture { isEditingFamilyName = true }
        }
        .padding(.horizontal, 20)
        .frame(minWidth: 144)
        .frame(maxWidth: 335)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEditingFamilyName ? Color(hex: "#EEF5E3") : .white))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#E3E3E3"), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
        .padding(.top, 10)
        .onTapGesture { isEditingFamilyName = true }
        .onChange(of: isEditingFamilyName) { _, editing in
            if !editing { commitFamilyName() }
        }
    }

    private var familyCard: some View {
        FamilyCardView(
            familyName: $familyName,
            members: members,
            extraMemberCount: extraMemberCount,
            onAddMember: {
                coordinator.navigateInBottomSheet(.addMoreMembers)
            },
            onCommitFamilyName: commitFamilyName
        )
    }

    struct MemberRow: View {
        let member: FamilyMember
        let onInvite: (UUID) async -> Void
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
                    // All members use MeetYourProfileView for consistency
                    coordinator.navigateInBottomSheet(.meetYourProfile(memberId: member.id))
                }

                // Action Area: Invite or Leave (Independent tap target)
                actionButton
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
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
                        .foregroundStyle(Color(hex: "#F04438"))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.clear, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "#F04438"), lineWidth: 1)
                        )
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
                    Task { @MainActor in
                        await onInvite(member.id)
                    }
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
                            .stroke(Color(hex: "#EEEEEE").opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: Color(hex: "#CECECE63").opacity(0.39), radius: 4.8)
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

// MARK: - Family Card Component

private struct FamilyCardView: View {
    @Binding var familyName: String
    let members: [FamilyMember]
    let extraMemberCount: Int
    let onAddMember: () -> Void
    let onCommitFamilyName: () -> Void
    
    @FocusState private var isEditingFamilyName: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // Label to clarify this is the family name
                    Text("Family Name")
                        .font(ManropeFont.regular.size(11))
                        .foregroundStyle(.grayScale110)
                        .padding(.top, 0)
                    
                    // Family name edit field
                    HStack(spacing: 12) {
                        TextField("", text: $familyName)
                            .font(NunitoFont.semiBold.size(22))
                            .foregroundStyle(Color(hex: "#303030"))
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($isEditingFamilyName)
                            .submitLabel(.done)
                            .onSubmit {
                                isEditingFamilyName = false
                                onCommitFamilyName()
                            }
                        Image("pen-line")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.grayScale100)
                            .onTapGesture { isEditingFamilyName = true }
                    }
                    .padding(.horizontal, 8)
                    .frame(minWidth: 144)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isEditingFamilyName ? Color(hex: "#EEF5E3") : .white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E3E3E3"), lineWidth: 0.5)
                    )
                    .contentShape(Rectangle())
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, 4)
                    .onTapGesture { isEditingFamilyName = true }
                    .onChange(of: isEditingFamilyName) { _, editing in
                        if !editing { onCommitFamilyName() }
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
            
            HStack {
                HStack(spacing: -12) {
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
                }
                
                Spacer()
                
                Button {
                    onAddMember()
                } label: {
                    GreenCapsule(title: "Add Member",icon: "tabler_plus", width: 111, height: 36, takeFullWidth: false, labelFont: NunitoFont.semiBold.size(12))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)

            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(lineWidth: 0.75)
                .foregroundStyle(Color(hex: "#EEEEEE"))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Family Card Preview

#Preview("Family Card") {
    FamilyCardPreview()
        .environment(WebService())
}

private struct FamilyCardPreview: View {
    @State private var familyName: String = "Smith Family"
    @FocusState private var isEditingFamilyName: Bool
    
    // Mock members data
    private let mockMembers: [FamilyMember] = [
        FamilyMember(id: UUID(), name: "John", color: "#E0BBE4", joined: true, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Sarah", color: "#BAE1FF", joined: true, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Emma", color: "#BAFFC9", joined: true, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Mike", color: "#FFB3BA", joined: false, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Lisa", color: "#FFDFBA", joined: true, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Tom", color: "#FFFFBA", joined: false, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Anna", color: "#E0BBE4", joined: true, imageFileHash: nil)
    ]
    
    private var extraMemberCount: Int {
        let maxShown = 6
        return max(mockMembers.count - maxShown, 0)
    }
    
    var body: some View {
        FamilyCardView(
            familyName: $familyName,
            members: mockMembers,
            extraMemberCount: extraMemberCount,
            onAddMember: {
                print("Add Member tapped in preview")
            },
            onCommitFamilyName: {
                print("Family name committed: \(familyName)")
            }
        )
        .background(Color(hex: "#F7F7F7"))
    }
}

#Preview("With Family") {
    let familyStore = FamilyStore()
    let coordinator = AppNavigationCoordinator()
    let webService = WebService()
    
    // Set up mock family data
    let mockSelfMember = FamilyMember(
        id: UUID(),
        name: "Alex",
        color: "#E0BBE4",
        joined: true,
        imageFileHash: nil
    )
    
    let mockOtherMembers: [FamilyMember] = [
        FamilyMember(id: UUID(), name: "Sarah", color: "#BAE1FF", joined: true, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Emma", color: "#BAFFC9", joined: true, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Mike", color: "#FFB3BA", joined: false, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Lisa", color: "#FFDFBA", joined: true, imageFileHash: nil),
        FamilyMember(id: UUID(), name: "Tom", color: "#FFFFBA", joined: false, imageFileHash: nil, invitePending: true),
        FamilyMember(id: UUID(), name: "Anna", color: "#B4E4FF", joined: true, imageFileHash: nil)
    ]
    
    let mockFamily = Family(
        name: "Smith Family",
        selfMember: mockSelfMember,
        otherMembers: mockOtherMembers,
        version: Int64(Date().timeIntervalSince1970)
    )
    
    // Set mock family data for preview
    familyStore.setMockFamilyForPreview(mockFamily)
    
    return NavigationStack {
        ManageFamilyView()
            .environment(familyStore)
            .environment(coordinator)
            .environment(webService)
    }
}

#Preview("Empty State") {
    NavigationStack {
        ManageFamilyView()
            .environment(FamilyStore())
            .environment(AppNavigationCoordinator())
            .environment(WebService())
    }
}
