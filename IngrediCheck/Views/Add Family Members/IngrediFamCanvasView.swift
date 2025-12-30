//
//  IngrediFamCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 16/10/25.
//

import SwiftUI
import DotLottie

struct GenerateAvatarTools: Identifiable {
    let id = UUID().uuidString
    var title: String
    var icon: String
    var tools: [ChipsModel]
}

enum AddFamilyMemberSheetOption: String, Identifiable {
    case meetYourIngrediFam
    case whatsYourName
    case addMoreMember
    case addMoreMembersMinimal
    case allSet
    case alreadyHaveAnAccount
    case doYouHaveAnInviteCode
    case generateAvatar
    case bringingYourAvatar
    case meetYourAvatar
    case letsScanSmarter
    case accessDenied
    case stayUpdated
    case preferenceAreReady
    case welcomeBack
    case whosThisFor
    case allSetToJoinYourFamily
    case enterYourInviteCode
    
    var id: String { self.rawValue }
}

struct IngrediFamCanvasView: View {
    
    @State var addFamilyMemberSheetOption: AddFamilyMemberSheetOption? = .allSet
    @State var isExpandedMinimal: Bool = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.grayScale10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale60)
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .frame(height: 700)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
            
            VStack(spacing: 20) {
                Button("welcomeBack") {
                    addFamilyMemberSheetOption = .welcomeBack
                }
                Button("whosThisFor") {
                    addFamilyMemberSheetOption = .whosThisFor
                }
                Button("allSetToJoinYourFamily") {
                    addFamilyMemberSheetOption = .allSetToJoinYourFamily
                }
                Button("enterYourInviteCode") {
                    addFamilyMemberSheetOption = .enterYourInviteCode
                }
                Button("addMoreMember") {
                    addFamilyMemberSheetOption = .addMoreMember
                }
                Button("addMoreMembersMinimal") {
                    addFamilyMemberSheetOption = .addMoreMembersMinimal
                }
                Button("allSet") {
                    addFamilyMemberSheetOption = .allSet
                }
                Button("alreadyHaveAnAccount") {
                    addFamilyMemberSheetOption = .alreadyHaveAnAccount
                }
                Button("doYouHaveAnInviteCode") {
                    addFamilyMemberSheetOption = .doYouHaveAnInviteCode
                }
                Button("meetYourIngrediFam") {
                    addFamilyMemberSheetOption = .meetYourIngrediFam
                }
                Button("whatsYourName") {
                    addFamilyMemberSheetOption = .whatsYourName
                }
                Button("generateAvatar") {
                    addFamilyMemberSheetOption = .generateAvatar
                }
                Button("meetYourAvatar") {
                    addFamilyMemberSheetOption = .meetYourAvatar
                }
                Button("letsScanSmarter") {
                    addFamilyMemberSheetOption = .letsScanSmarter
                }
                Button("accessDenied") {
                    addFamilyMemberSheetOption = .accessDenied
                }
                Button("stayUpdated") {
                    addFamilyMemberSheetOption = .stayUpdated
                }
                Button("preferenceAreReady") {
                    addFamilyMemberSheetOption = .preferenceAreReady
                }
                Button("bringYourAvatar") {
                    addFamilyMemberSheetOption = .bringingYourAvatar
                }
            }
        }
        CustomSheet(item: $addFamilyMemberSheetOption,
                    cornerRadius: 34) { sheet in
            switch sheet {
            case .addMoreMember:
                AddMoreMembers()
            case .addMoreMembersMinimal:
                AddMoreMembersMinimal()
            case .allSet:
                AllSet()
            case .alreadyHaveAnAccount:
                AlreadyHaveAnAccount()
                case .doYouHaveAnInviteCode:
                    DoYouHaveAnInviteCode()
            case .meetYourIngrediFam:
                MeetYourIngrediFam()
            case .whatsYourName:
                WhatsYourName()
            case .generateAvatar:
                GenerateAvatar(
                    isExpandedMinimal: $isExpandedMinimal,
                    randomPressed: { _ in },
                    generatePressed: { _ in }
                )
            case .bringingYourAvatar:
                IngrediBotWithText(text: "Bringing your avatar to life... it's going to be awesome!")
            case .meetYourAvatar:
                MeetYourAvatar()
            case .letsScanSmarter:
                LetsScanSmarter()
            case .accessDenied:
                AccessDenied()
            case .stayUpdated:
                StayUpdated()
            case .preferenceAreReady:
                PreferenceAreReady()
            case .welcomeBack:
                WelcomeBack()
            case .whosThisFor:
                WhosThisFor()
            case .allSetToJoinYourFamily:
                AllSetToJoinYourFamily()
            case .enterYourInviteCode:
                EnterYourInviteCode()
            }
        }
    }
}

struct GenerateAvatar: View {
    @Environment(MemojiStore.self) private var memojiStore
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(FamilyStore.self) private var familyStore
    
    @State var toolIcons: [String] = [
        "family-member",
        "gesture",
        "hair-style",
        "skin-tone",
        "accessories",
        "color-theme"
    ]
    
    @State var familyMember: [UserModel] = [
        UserModel(familyMemberName: "baby-boy", familyMemberImage: "baby-boy", backgroundColor: Color(hex: "FFD9B5")), // Baby Boy - Age (0-4)
        UserModel(familyMemberName: "baby-girl", familyMemberImage: "baby-girl", backgroundColor: Color(hex: "F9C6D0")), // Baby Girl - Age (0-4)
        UserModel(familyMemberName: "young-girl", familyMemberImage: "image-bg5", backgroundColor: Color(hex: "B8E6FF")), // Young Girl - Age (4-25)
        UserModel(familyMemberName: "young-boy", familyMemberImage: "Young-Son", backgroundColor: Color(hex: "FFF6B3")), // Young Boy - Age (4-25)
        UserModel(familyMemberName: "mother", familyMemberImage: "image 2", backgroundColor: Color(hex: "E6D5F5")), // Adult Woman - Age (25-50)
        UserModel(familyMemberName: "father", familyMemberImage: "adult-man", backgroundColor: Color(hex: "D4E6F1")), // Adult Man - Age (25-50)
        UserModel(familyMemberName: "grandfather", familyMemberImage: "image-bg3", backgroundColor: Color(hex: "BFF0D4")),
        UserModel(familyMemberName: "grandmother", familyMemberImage: "image-bg2", backgroundColor: Color(hex: "A7D8F0"))
    ]
    
    @State var selectedFamilyMember: UserModel = UserModel(familyMemberName: "baby-boy", familyMemberImage: "baby-boy", backgroundColor: Color(hex: "FFD9B5"))
    @State var familyIdx: Int = 0
    
    // Restore state from memojiStore when view appears
    private func restoreState() {
        // Restore selected family member
        if !memojiStore.selectedFamilyMemberName.isEmpty,
           let existingMember = familyMember.first(where: { $0.name == memojiStore.selectedFamilyMemberName }) {
            selectedFamilyMember = existingMember
            hasSelectedFamilyMember = true // User has previously selected this
            if let idx = familyMember.firstIndex(where: { $0.name == memojiStore.selectedFamilyMemberName }) {
                familyIdx = idx
            } else {
                familyIdx = 0
                selectedFamilyMember = familyMember[0] // Ensure valid selection
            }
        } else {
            // No previous selection - nothing should appear selected
            selectedFamilyMember = familyMember[0]
            familyIdx = 0
            hasSelectedFamilyMember = false
        }
        
        // Restore other selections
        selectedGestureIcon = memojiStore.selectedGestureIcon
        selectedHairStyleIcon = memojiStore.selectedHairStyleIcon
        selectedSkinToneIcon = memojiStore.selectedSkinToneIcon
        selectedAccessoriesIcon = memojiStore.selectedAccessoriesIcon
        selectedColorThemeIcon = memojiStore.selectedColorThemeIcon
        
        // Restore selected tool and then restore idx based on selected icon
        selectedTool = memojiStore.selectedTool
        restoreIdxForTool(selectedTool)
    }
    
    // Save state to memojiStore when selections change
    private func saveState() {
        memojiStore.selectedFamilyMemberName = selectedFamilyMember.name
        memojiStore.selectedFamilyMemberImage = selectedFamilyMember.image
        memojiStore.selectedTool = selectedTool
        memojiStore.currentToolIndex = idx
        memojiStore.selectedGestureIcon = selectedGestureIcon
        memojiStore.selectedHairStyleIcon = selectedHairStyleIcon
        memojiStore.selectedSkinToneIcon = selectedSkinToneIcon
        memojiStore.selectedAccessoriesIcon = selectedAccessoriesIcon
        memojiStore.selectedColorThemeIcon = selectedColorThemeIcon
    }
    
    @Binding var isExpandedMinimal: Bool
    @Namespace private var animation
    
    @State var tools: [GenerateAvatarTools] = [
        GenerateAvatarTools(
            title: "Gesture",
            icon: "gesture",
            tools: [
                ChipsModel(name: "Wave", icon: "wave"),
                ChipsModel(name: "Thumbs Up", icon: "thumbs-up"),
                ChipsModel(name: "Heart Hands", icon: "heart-hands"),
                ChipsModel(name: "Phone in Hand", icon: "phone-in-hand"),
                ChipsModel(name: "Peace", icon: "peace"),
                ChipsModel(name: "Pointing", icon: "pointing")
            ]
        ),
        GenerateAvatarTools(
            title: "Hair Style",
            icon: "hair-style",
            tools: [
                ChipsModel(name: "Short hair", icon: "short-hair"),
                ChipsModel(name: "Long hair", icon: "long-hair"),
                ChipsModel(name: "Ponytail", icon: "ponytail"),
                ChipsModel(name: "Curly hair", icon: "curly-hair"),
                ChipsModel(name: "Bun", icon: "bun"),
                ChipsModel(name: "Bald", icon: "bald"),
                ChipsModel(name: "Short Spiky", icon: "Short Spiky"),
                ChipsModel(name: "Braided", icon: "Braided"),
                ChipsModel(name: "Medium Curly", icon: "medium-curely")
            ]
        ),
        GenerateAvatarTools(
            title: "Skin Tone",
            icon: "skin-tone",
            tools: [
                ChipsModel(name: "Very Light", icon: "very-light"),
                ChipsModel(name: "Light", icon: "light"),
                ChipsModel(name: "Medium Light", icon: "medium-light"),
                ChipsModel(name: "Medium", icon: "medium"),
                ChipsModel(name: "Medium Dark", icon: "Medium-Dark"),
                ChipsModel(name: "Very Dark", icon: "very-dark")
            ]
        ),
        GenerateAvatarTools(
            title: "Accessories",
            icon: "accessories",
            tools: [
                ChipsModel(name: "Glasses", icon: "glasses"),
                ChipsModel(name: "Hat", icon: "hat"),
                ChipsModel(name: "Earrings", icon: "earrings"),
                ChipsModel(name: "Sunglasses", icon: "sunglasses"),
                ChipsModel(name: "Cap", icon: "cap")
            ]
        ),
        GenerateAvatarTools(
            title: "Color Theme",
            icon: "color-theme",
            tools: [
                ChipsModel(name: "Pastel Blue", icon: "pastel-blue"),
                ChipsModel(name: "Warm Pink", icon: "warm-pink"),
                ChipsModel(name: "Soft Green", icon: "soft-green"),
                ChipsModel(name: "Lavender", icon: "lavender"),
                ChipsModel(name: "Cream", icon: "cream"),
                ChipsModel(name: "Mint", icon: "mint"),
                ChipsModel(name: "Transparent", icon: "transparent")
            ]
        )
    ]
    
    @State var isExpandedMaximal: Bool = false
    
    // State variables synced with memojiStore
    @State var selectedTool: String = "family-member"
    @State var idx: Int = 0
    @State var selectedGestureIcon: String? = nil
    @State var selectedHairStyleIcon: String? = nil
    @State var selectedSkinToneIcon: String? = nil
    @State var selectedAccessoriesIcon: String? = nil
    @State var selectedColorThemeIcon: String? = nil
    @State var hasSelectedFamilyMember: Bool = false // Track if user has actively selected a family member
    
    var randomPressed: (MemojiSelection) -> Void = { _ in }
    var generatePressed: (MemojiSelection) -> Void = { _ in }
    
    // Helper function to get selected icon for a tool category
    func getSelectedIcon(for toolIcon: String) -> String? {
        switch toolIcon {
        case "family-member":
            return selectedFamilyMember.image
        case "gesture":
            return selectedGestureIcon
        case "hair-style":
            return selectedHairStyleIcon
        case "skin-tone":
            return selectedSkinToneIcon
        case "accessories":
            return selectedAccessoriesIcon
        case "color-theme":
            return selectedColorThemeIcon
        default:
            return nil
        }
    }
    
    // Helper function to get primary icon name for a tool category (for selected state)
    func getPrimaryIcon(for toolIcon: String) -> String? {
        switch toolIcon {
        case "family-member":
            return "family-member-Primary"
        case "gesture":
            return "gesture-Primary"
        case "hair-style":
            return "hair-style-Primary"
        case "skin-tone":
            return "skin-tone-Primary"
        case "accessories":
            return "accessories-Primary"
        case "color-theme":
            return "color-theme-Primary"
        default:
            return nil
        }
    }
    
    // Helper function to restore idx based on selected icon for a tool category
    private func restoreIdxForTool(_ toolIcon: String) {
        // Skip family-member as it doesn't use idx
        guard toolIcon != "family-member" else {
            return
        }
        
        // Get the tool index (0-based for tools array: gesture=0, hair-style=1, etc.)
        guard let toolIconIndex = toolIcons.firstIndex(of: toolIcon),
              toolIconIndex > 0 else {
            idx = 0
            return
        }
        
        let toolIdx = toolIconIndex - 1 // Convert to tools array index
        guard toolIdx < tools.count else {
            idx = 0
            return
        }
        
        // Get the selected icon for this tool category
        let selectedIcon = getSelectedIcon(for: toolIcon)
        
        // Find the index of the selected icon in the tools array
        if let selectedIcon = selectedIcon,
           let iconIndex = tools[toolIdx].tools.firstIndex(where: { $0.icon == selectedIcon }) {
            idx = iconIndex
        } else {
            // If no selection, default to first item
            idx = 0
        }
    }
    
    // Helper function to set selected icon for a tool category
    func setSelectedIcon(for toolIcon: String, icon: String?) {
        switch toolIcon {
        case "gesture":
            selectedGestureIcon = icon
            // Update idx to match the selected icon's position in gesture tools
            if let icon = icon, let iconIndex = tools[0].tools.firstIndex(where: { $0.icon == icon }) {
                idx = iconIndex
            }
        case "hair-style":
            selectedHairStyleIcon = icon
            // Update idx to match the selected icon's position in hair-style tools
            if let icon = icon, let iconIndex = tools[1].tools.firstIndex(where: { $0.icon == icon }) {
                idx = iconIndex
            }
        case "skin-tone":
            selectedSkinToneIcon = icon
            // Update idx to match the selected icon's position in skin-tone tools
            if let icon = icon, let iconIndex = tools[2].tools.firstIndex(where: { $0.icon == icon }) {
                idx = iconIndex
            }
        case "accessories":
            selectedAccessoriesIcon = icon
            // Update idx to match the selected icon's position in accessories tools
            if let icon = icon, let iconIndex = tools[3].tools.firstIndex(where: { $0.icon == icon }) {
                idx = iconIndex
            }
        case "color-theme":
            selectedColorThemeIcon = icon
            // Update idx to match the selected icon's position in color-theme tools
            if let icon = icon, let iconIndex = tools[4].tools.firstIndex(where: { $0.icon == icon }) {
                idx = iconIndex
            }
        default:
            break
        }
        saveState()
    }
    
    private func buildMemojiSelection() -> MemojiSelection? {
        // Require explicit family member selection - don't fall back to default
        guard hasSelectedFamilyMember else {
            return nil
        }
        
        // Note: We don't validate against familyMember array here because:
        // - The array is manipulated for UI display (selected member is removed from list)
        // - selectedFamilyMember is a valid UserModel object when hasSelectedFamilyMember is true
        // - The array manipulation in familyMemberListView is just for showing "other" members
        
        let gesture = selectedGestureIcon ?? tools[0].tools.first?.icon ?? "wave"
        let hair = selectedHairStyleIcon ?? tools[1].tools.first?.icon ?? "short-hair"
        let skinTone = selectedSkinToneIcon ?? tools[2].tools.first?.icon ?? "light"
        // Don't fallback to default for optional fields - if user doesn't select, send nil to API
        let accessory = selectedAccessoriesIcon
        let colorTheme = selectedColorThemeIcon
        
        // Format: "baby-boy age (0 to 4)"
        let familyTypeWithAge = "\(selectedFamilyMember.name.lowercased()) \(getAgeRangeForAPI(for: selectedFamilyMember.name))"
        
        return MemojiSelection(
            familyType: familyTypeWithAge,
            gesture: gesture,
            hair: hair,
            skinTone: skinTone,
            accessory: accessory,
            colorThemeIcon: colorTheme
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
//                if geometry.size.height >= 500 {
//                    VStack {
//                        ScrollView(showsIndicators: false) {
//                            VStack(spacing: 32) {
//                                
//                                if isExpandedMaximal == false {
//                                    VStack(spacing: 4) {
//                                        Image(.funGuy)
//                                        
//                                        Text("AI Memojis")
//                                            .font(ManropeFont.bold.size(16))
//                                            .foregroundStyle(.grayScale150)
//                                        
//                                        Text("Create Personalized family Avatar")
//                                            .font(ManropeFont.medium.size(12))
//                                            .foregroundStyle(.grayScale150)
//                                    }
//                                    
//                                    Text("Generate Avatar")
//                                        .font(ManropeFont.bold.size(14))
//                                        .foregroundStyle(.grayScale150)
//                                        .frame(maxWidth: .infinity, alignment: .leading)
//                                }
//                                
//                                VStack(spacing: 20) {
//                                    VStack(alignment: .leading, spacing: 8) {
//                                        HStack(spacing: 8) {
//                                            Image(.familyMember)
//                                                .resizable()
//                                                .renderingMode(.template)
//                                                .foregroundStyle(.grayScale150)
//                                                .frame(width: 22, height: 24)
//                                            
//                                            Text("Family Member")
//                                                .font(ManropeFont.semiBold.size(16))
//                                                .foregroundStyle(.grayScale150)
//                                        }
//                                        
//                                        Text("Tell us how you're related to them so we can create the perfect avatar!")
//                                            .font(ManropeFont.medium.size(12))
//                                            .foregroundStyle(.grayScale120)
//                                            .frame(maxWidth: .infinity, alignment: .leading)
//                                    }
//                                    
//                                    CollapseFamilyList(collapsed: $isExpandedMaximal, familyNames: $familyMember, selectedItem: $selectedFamilyMember)
//                                }
//                                
//                                .padding(.bottom, 30)
//                                
//                                
//                                if isExpandedMaximal == false {
//                                    ForEach(tools) { tool in
//                                        VStack(alignment: .leading, spacing: 8) {
//                                            HStack(spacing: 8) {
//                                                Image(tool.icon)
//                                                    .resizable()
//                                                    .renderingMode(.template)
//                                                    .foregroundStyle(.grayScale150)
//                                                    .frame(width: 24, height: 24)
//                                                
//                                                Text(tool.title)
//                                                    .font(ManropeFont.semiBold.size(16))
//                                                    .foregroundStyle(.grayScale150)
//                                            }
//                                            
//                                            FlowLayout(horizontalSpacing: 8, verticalSpacing: 12) {
//                                                ForEach(tool.tools) { innerTool in
//                                                    
//                                                    Button {
//                                                        
//                                                    } label: {
//                                                        HStack(spacing: 4) {
//                                                            Image(innerTool.icon ?? "")
//                                                                .resizable()
//                                                                .frame(width: 24, height: 24)
//                                                            
//                                                            Text(innerTool.name)
//                                                                .font(ManropeFont.medium.size(14))
//                                                                .foregroundStyle(.grayScale150)
//                                                        }
//                                                        .padding(.vertical, 8)
//                                                        .padding(.trailing, 16)
//                                                        .padding(.leading, 12)
//                                                        .overlay(
//                                                            RoundedRectangle(cornerRadius: 40)
//                                                                .stroke(lineWidth: 1)
//                                                                .foregroundStyle(.grayScale60)
//                                                        )
//                                                    }
//                                                }
//                                            }
//                                        }
//                                    }
//                                }
//                                
//                            }
//                            .padding(.horizontal, 20)
//                            .padding(.top, 30)
//                            .padding(.bottom, 5)
//                        }
//                        .padding(.top, 20)
//                        
//                        HStack(spacing: 16) {
//                            Button {
//                                randomPressed()
//                            } label: {
//                                GreenOutlinedCapsule(image: "ai-stick", title: "Random")
//                            }
//
//                            
//                            Button {
//                                generatePressed()
//                            } label: {
//                                GreenCapsule(title: "Generate", icon: "stars-generate")
//                            }
//                        }
//                        .padding(.horizontal, 20)
//                    }
//                } else {
                    if isExpandedMinimal {
                        VStack {
                            Spacer()
                            selectedMemberRow()
                                
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .matchedGeometryEffect(id: "circle", in: animation)
                    } else {
                        VStack(spacing: 22) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 8) {
                                    Button {
                                        // Navigate back to the previous route, or default to whatsYourName
                                        let previousRoute = memojiStore.previousRouteForGenerateAvatar ?? .whatsYourName
                                        coordinator.navigateInBottomSheet(previousRoute)
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.black)
                                            .frame(width: 24, height: 24)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Text("Generate Avatar For : @" + (memojiStore.displayName ?? ""))
                                        .font(ManropeFont.bold.size(14))
                                        .foregroundStyle(.grayScale150)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                VStack(spacing: 0) {
                                    ScrollViewReader { proxy in
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 35) {
                                                ForEach(toolIcons, id: \.self) { ele in
                                                    GenerateAvatarToolPill(
                                                        icon: ele,
                                                        title: ele,
                                                        isSelected: $selectedTool,
                                                        selectedItemIcon: getSelectedIcon(for: ele),
                                                        primaryIcon: getPrimaryIcon(for: ele)
                                                    ) {
                                                        restoreIdxForTool(ele)
                                                        selectedTool = ele
                                                    }
                                                    .id(ele)
                                                }
                                            }
                                            .padding(.horizontal,25)
                                        }
                                        .onChange(of: selectedTool) { _, newValue in
                                            withAnimation {
                                                proxy.scrollTo(newValue, anchor: .center)
                                            }
                                        }
                                    }
                                    
                                    // Rectangle indicator above Divider, aligned with selected tool
                                    ScrollViewReader { proxy in
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 35) {
                                                ForEach(toolIcons, id: \.self) { ele in
                                                    Group {
                                                        if ele == selectedTool {
                                                            RoundedRectangle(cornerRadius: 1)
                                                                .fill(Color(hex: "#91B640"))
                                                                .frame(width: 28, height: 2)
                                                                .matchedGeometryEffect(id: "selectedIndicator", in: animation)
                                                        } else {
                                                            RoundedRectangle(cornerRadius: 1)
                                                                .fill(Color.clear)
                                                                .frame(width: 28, height: 2)
                                                        }
                                                    }
                                                    .id(ele)
                                                }
                                            }
                                            .padding(.horizontal,25)
                                        }
                                        .frame(height: 2)
                                        .onChange(of: selectedTool) { _, newValue in
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                proxy.scrollTo(newValue, anchor: .center)
                                            }
                                        }
                                    }
                                    .padding(.top, 9)
                                    
                                    Divider()
                                       
                                }
                                
                                VStack {
                                    switch selectedTool {
                                    case "family-member":
                                        minimalFamilySelector()
                                        
                                    case "gesture":
                                        minimalToolsSelector(toolIdx: 0)
                                        
                                    case "hair-style":
                                        minimalToolsSelector(toolIdx: 1)
                                        
                                    case "skin-tone":
                                        minimalToolsSelector(toolIdx: 2)
                                        
                                    case "accessories":
                                        minimalToolsSelector(toolIdx: 3)
                                        
                                    case "color-theme":
                                        minimalToolsSelector(toolIdx: 4)
                                        
                                    default:
                                        EmptyView()
                                    }
                                }	
                                // Removed padding to allow scrolling to phone edges for all selectors
                                // .padding(.horizontal, selectedTool == "family-member" ? 0 : 20)
                            }
                            
                            HStack(alignment: .top){
                                VStack(alignment: .leading){
                                    // Check if any tool category is selected
                                    let hasSelections = hasSelectedFamilyMember ||
                                                       selectedGestureIcon != nil ||
                                                       selectedHairStyleIcon != nil ||
                                                       selectedSkinToneIcon != nil ||
                                                       selectedAccessoriesIcon != nil ||
                                                       selectedColorThemeIcon != nil
                                    
                                    Text("Selected")
                                        .font(ManropeFont.medium.size(12))
                                        .foregroundStyle(hasSelections ? .grayScale130 : .grayScale70)
                                    HStack(spacing: 8) {
                                        // Selected icons row - show family member immediately when selected
                                        // Family member (show if user has actively selected it)
                                        if hasSelectedFamilyMember, let familyIcon = getSelectedIcon(for: "family-member") {
                                            Image(familyIcon)
                                                .resizable()
                                                .scaledToFit()
                                               .frame(width: 20, height: 20)
                                        }
                                        
                                        // Gesture (only show if selected)
                                        if let gestureIcon = getSelectedIcon(for: "gesture") {
                                            Image(gestureIcon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                        }
                                        
                                        // Hair style (only show if selected)
                                        if let hairIcon = getSelectedIcon(for: "hair-style") {
                                            Image(hairIcon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                        }
                                        
                                        // Skin tone (only show if selected)
                                        if let skinToneIcon = getSelectedIcon(for: "skin-tone") {
                                            Image(skinToneIcon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                        }
                                        
                                        // Accessories (only show if selected)
                                        if let accessoriesIcon = getSelectedIcon(for: "accessories") {
                                            Image(accessoriesIcon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                        }
                                        
                                        // Color theme (only show if selected)
                                        if let colorThemeIcon = getSelectedIcon(for: "color-theme") {
                                            Image(colorThemeIcon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                        }
                                        
                                        Spacer()
                                    }
                                   
                                }
                                .frame(width: 163)
//                                .padding(.horizontal, 20)
                                // Generate button
                                Button {
                                    if let selection = buildMemojiSelection() {
                                        generatePressed(selection)
                                    }
                                } label: {
                                    GreenCapsule(title: "Generate", icon: "stars-generate")
                                }
                                .disabled(!hasSelectedFamilyMember)
                                .opacity(hasSelectedFamilyMember ? 1.0 : 0.6)
                            }.padding(.horizontal, 20)
                        }
                    }
//                }
            }
            .padding(.top, -20) // Reduce top spacing after drag handle overlay
            .overlay(alignment: .bottom) {
                if isExpandedMinimal {
                    familyMemberListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.neutral500)
                    .frame(width: 60, height: 4)
                    .padding(.top, 11)
                , alignment: .top
            )
            .animation(.easeInOut, value: isExpandedMinimal)
            .onAppear {
                restoreState()
                // Ensure we always have a valid family member selected
                if !familyMember.contains(where: { $0.name == selectedFamilyMember.name }) {
                    selectedFamilyMember = familyMember[0]
                    familyIdx = 0
                    hasSelectedFamilyMember = false // Fallback, not a user selection
                }
            }
            .onChange(of: selectedTool) { _, newValue in
                restoreIdxForTool(newValue)
                saveState()
            }
            .onChange(of: idx) { _, _ in
                saveState()
            }
            .onChange(of: selectedFamilyMember.name) { _, _ in
                saveState()
            }
            .onChange(of: selectedFamilyMember.image) { _, _ in
                saveState()
            }
        }
    }
    
    @ViewBuilder
    func minimalToolsSelector(toolIdx: Int) -> some View {
        // Map toolIdx to toolIcons: 0->gesture, 1->hair-style, 2->skin-tone, 3->accessories, 4->color-theme
        let toolCategory = toolIcons[toolIdx + 1] // +1 because toolIcons[0] is "family-member"
        let selectedIcon = getSelectedIcon(for: toolCategory)
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(tools[toolIdx].tools) { tool in
                    let isSelected = selectedIcon == tool.icon
                    
                    Button {
                        setSelectedIcon(for: toolCategory, icon: tool.icon)
                    } label: {
                        VStack(spacing: 8) {
                            // Icon with border when selected
                            ZStack {
                                // Background rectangle with color
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(Color(hex: "#F9F9F9"))
//                                    .frame(width: 52, height: 52)
                                
                                // Icon image
                                if let icon = tool.icon {
                                    Image(icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 43.34, height: 43.34)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                // Border - conditional based on selection
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected ? Color(hex: "#91B640") : .grayScale40,
                                        lineWidth: isSelected ? 1 : 0.5
                                    )
                                    .frame(width: 70, height: 70)
                            }
                            
                            // Tool name label
                            Text(tool.name)
                                .font(ManropeFont.medium.size(12))
                                .foregroundStyle(.grayScale110)
                        }
//                        .padding(.top, 22)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
           .padding(.horizontal, 20)
        }
    }
    
    // Helper function to get age range for family member (for UI display)
    private func getAgeRange(for memberName: String) -> String {
        switch memberName.lowercased() {
        case "baby-boy", "baby-girl":
            return "Age (0-4)"
        case "young-girl", "young-boy":
            return "Age (4-25)"
        case "father", "mother":
            return "Age (25-50)"
        case "grandfather", "grandmother":
            return "Age (50+)"
        default:
            return "Age (4-25)"
        }
    }
    
    // Helper function to get age range for API (format: "age (0 to 4)")
    private func getAgeRangeForAPI(for memberName: String) -> String {
        switch memberName.lowercased() {
        case "baby-boy", "baby-girl":
            return "age (0 to 4)"
        case "young-girl", "young-boy":
            return "age (4 to 25)"
        case "father", "mother":
            return "age (25 to 50)"
        case "grandfather", "grandmother":
            return "age (50+)"
        default:
            return "age (4 to 25)"
        }
    }
    
    @ViewBuilder
    func minimalFamilySelector() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(familyMember) { member in
                    let isSelected = hasSelectedFamilyMember && selectedFamilyMember.name == member.name
                    
                    Button {
                        hasSelectedFamilyMember = true
                        selectedFamilyMember = member
                        if let idx = familyMember.firstIndex(where: { $0.name == member.name }) {
                            familyIdx = idx
                        }
                        saveState()
                    } label: {
                        VStack(spacing: 8) {
                            // Avatar with green border when selected
                            ZStack {
                                // Background circle with color
                                Circle()
                                    .fill(Color(hex: "#F9F9F9"))
                                    .frame(width: 52, height: 52)
                                
                                // Avatar image
                                Image(member.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 43.34, height: 43.34)
                                    .clipShape(Circle())
                                
                                
                                RoundedRectangle(cornerRadius: 12)
                                                                   .stroke(
                                                                       isSelected ? Color(hex: "#91B640") : .grayScale40,
                                                                       lineWidth: isSelected ? 1 : 0.5
                                                                   )
                                                                   .frame(width: 70, height: 70)
                            }
                            
                            // Age range label
                            Text(getAgeRange(for: member.name))
                                .font(ManropeFont.medium.size(12))
                                .foregroundStyle( .grayScale110)
                        }
//                        .padding(.top, 22)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    func selectedMemberRow() -> some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(Color(hex: "F9F9F9"))
                    
                    Image(selectedFamilyMember.image)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .shadow(color: Color(hex: "DEDDDD"), radius: 3.5, x: 0, y: 0)
                }
                
                Text(selectedFamilyMember.name)
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(.grayScale150)
            }
            
            Spacer()
            
            Image(.arrow)
                .resizable()
                .frame(width: 24, height: 24)
                .rotationEffect(Angle(degrees: 180))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC").opacity(0.4), radius: 5, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(lineWidth: 0.5)
                        .foregroundStyle(.grayScale40)
                )
            
        )
        .onTapGesture {
            withAnimation(.easeInOut) {
                isExpandedMinimal.toggle()
            }
        }
    }
    
    @ViewBuilder
    func familyMemberListView() -> some View {
        VStack {
            ScrollView {
                VStack {
                    ForEach(familyMember) { member in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(Color(hex: "F9F9F9"))
                                
                                Image(member.image)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .shadow(color: Color(hex: "DEDDDD"), radius: 3.5, x: 0, y: 0)
                            }
                            
                            Text(member.name)
                                .font(ManropeFont.medium.size(14))
                                .foregroundStyle(.grayScale150)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            let temp = selectedFamilyMember
                            // Update familyIdx before modifying the array
                            if let idx = familyMember.firstIndex(where: { $0.name == member.name }) {
                                familyIdx = idx
                            }
                            selectedFamilyMember = member
                            hasSelectedFamilyMember = true
                            familyMember.removeAll { $0.name == member.name }
                            familyMember.append(temp)
                            saveState()
                            
                            isExpandedMinimal = false
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.30)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.grayScale10)
                .shadow(color: Color(hex: "ECECEC"), radius: 5, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.5)
                .foregroundStyle(.grayScale40)
        )
        .padding(.bottom, 60)
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .offset(y: -30)
    }
}

struct MeetYourAvatar: View {
    let image: UIImage?
    let backgroundColorHex: String?
    let regeneratePressed: () -> Void
    let assignedPressed: () -> Void
    @State private var showConfetti = false
    @Environment(MemojiStore.self) private var memojiStore
    
    // Helper function to get the display name with possessive form
    private var displayText: String {
        if let typedName = memojiStore.displayName, !typedName.isEmpty {
            // Use the typed name with possessive form
            return "Meet \(typedName)'s avatar,\nlooking good!"
        } else {
            // Fallback to family member type if no typed name
            let memberType = memojiStore.selectedFamilyMemberName
            let possessiveName = getPossessiveName(for: memberType)
            return "Meet your \(possessiveName) avatar,\nlooking good!"
        }
    }
    
    // Helper function to convert family member type to possessive form
    private func getPossessiveName(for memberType: String) -> String {
        switch memberType.lowercased() {
        case "father":
            return "dad's"
        case "mother":
            return "mom's"
        case "grandfather":
            return "grandfather's"
        case "grandmother":
            return "grandmother's"
        case "baby-boy":
            return "baby boy's"
        case "baby-girl":
            return "baby girl's"
        case "young-boy":
            return "young boy's"
        case "young-girl":
            return "young girl's"
        default:
            return "\(memberType)'s"
        }
    }
    
    init(image: UIImage? = nil, backgroundColorHex: String? = nil, regeneratePressed: @escaping () -> Void = {}, assignedPressed: @escaping () -> Void = {}) {
        self.image = image
        self.backgroundColorHex = backgroundColorHex
        self.regeneratePressed = regeneratePressed
        self.assignedPressed = assignedPressed
    }
    
    var body: some View {
        let circleColor = Color(hex: backgroundColorHex ?? "F2F2F2")
        
        VStack(spacing: 20) {
            // Avatar with background circle
            ZStack {
                // Background circle (behind the image)
                Circle()
                    .fill(circleColor)
                    .frame(width: 137, height: 137)
                
                // Memoji image on top (transparent PNG should show circle through)
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.original) // Preserve transparency
                        .scaledToFit() // Preserve aspect ratio
                        .frame(width: 137, height: 137)
                        .clipShape(Circle())
                }
            }
            
            VStack(spacing: 40) {
                Text(displayText)
                    .font(NunitoFont.bold.size(18))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    Button {
                        regeneratePressed()
                    } label: {
                        GreenOutlinedCapsule(image: "stars-generate", title: "Regenerate")
                    }
                    
                    Button {
                        assignedPressed()
                    } label: {
                        GreenCapsule(title: "Assign")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .overlay {
            if showConfetti {
                DotLottieAnimation(
                    fileName: "Confetti",
                    config: AnimationConfig(autoplay: true, loop: true)
                )
                .view()
                .ignoresSafeArea()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showConfetti = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.4) {
                showConfetti = false
            }
        }
    }
}

struct LetsScanSmarter: View {
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Let's scan smarter")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Text("Your camera helps you quickly add products by scanning labels — it’s safe and private. We never record or share anything without your permission.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                Button {
                    
                } label: {
                    Text("Later")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }

                
                
                GreenCapsule(title: "Enable")
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .navigationBarBackButtonHidden(true)
    }
}

struct AccessDenied: View {
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Access Denied !")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)

                Text("IngrediCheck needs camera access to scan products and give you personalized recommendations. Please enable it in settings to continue.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }

            GreenCapsule(title: "Open Settings")
                .frame(width: 156)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .navigationBarBackButtonHidden(true)
    }
}

struct StayUpdated: View {
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Stay updated !")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)

                Text("We’ll send you helpful meal tips, reminders, and important updates—only when you want them.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button {
                    
                } label: {
                    Text("Remind me Later")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }

                GreenCapsule(title: "Allow")
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .navigationBarBackButtonHidden(true)
    }
}

struct PreferenceAreReady: View {
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("All set! Your IngrediFam’s\npreferences are ready.")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)

                Text("Tap on any member to view their summary")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }

            GreenCapsule(title: "Continue")
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .navigationBarBackButtonHidden(true)
    }
}

struct AlreadyHaveAnAccount: View {
    let yesPressed: () -> Void
    let noPressed: () -> Void
    
    init(yesPressed: @escaping () -> Void = {}, noPressed: @escaping () -> Void = {}) {
        self.yesPressed = yesPressed
        self.noPressed = noPressed
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Are you an existing user?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.bottom ,12)

                Text("Have you used IngrediCheck earlier? If yes, continue. ")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
                Text("If not, start new.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {
                Button {
                    yesPressed()
                } label: {
                    Text("Yes, continue")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(height: 52)
                        .frame(minWidth: 152)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .foregroundStyle(.grayScale40)
                        )
                }

                Button {
                    noPressed()
                } label: {
                    GreenCapsule(title: "No, start new")
                }
                
            }
            .padding(.bottom, 32)

//            Text("You can switch anytime before continuing.")
//                .font(ManropeFont.regular.size(12))
//                .foregroundStyle(.grayScale120)
//                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct DoYouHaveAnInviteCode: View {
    let yesPressed: (() -> Void)?
    let noPressed: (() -> Void)?
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    init(yesPressed: (() -> Void)? = nil, noPressed: (() -> Void)? = nil) {
        self.yesPressed = yesPressed
        self.noPressed = noPressed
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Do you have an invite code?")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        coordinator.navigateInBottomSheet(.alreadyHaveAnAccount)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("Got a family invite to IngrediFam? Enter code.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)

            HStack(spacing: 16) {
               
               Button {
                    yesPressed?()
                
                    } label: {
                    Text("Enter invite code")
                                        .font(NunitoFont.semiBold.size(16))
                                        .foregroundStyle(.grayScale110)
                                        .frame(height: 52)
                                        .frame(minWidth: 152)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            Capsule()
                                                .foregroundStyle(.grayScale40)
                                        )
                                }
                Button {
                    noPressed?()
                } label: {
                    GreenCapsule(title: "No, Continue")
                }
                
            }
            .padding(.bottom, 20)

         
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct WelcomeBack: View {
    @Environment(AuthController.self) var authController
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Welcome back !")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        // Go back one bottom sheet route
                        coordinator.navigateInBottomSheet(.alreadyHaveAnAccount)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24) // comfortable tap target
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text("Log in to your existing IngrediCheck account.")
                    .font(ManropeFont.medium.size(12))                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {
                Button {
                    isSigningIn = true
                    authController.signInWithGoogle { result in
                        switch result {
                        case .success:
                            coordinator.showCanvas(.home)
                            isSigningIn = false
                        case .failure(let error):
                            print("Google Sign-In failed: \\(error.localizedDescription)")
                            isSigningIn = false
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("google_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Google")
                            .font(NunitoFont.semiBold.size(16))
                            .foregroundStyle(.grayScale150)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white, in: .capsule)
                    .overlay(
                        Capsule()
                            .stroke(Color.grayScale40, lineWidth: 1)
                    )
                }
                .disabled(isSigningIn)

                Button {
                    isSigningIn = true
                    authController.signInWithApple { result in
                        switch result {
                        case .success:
                            coordinator.showCanvas(.home)
                            isSigningIn = false
                        case .failure(let error):
                            print("Apple Sign-In failed: \\(error.localizedDescription)")
                            isSigningIn = false
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("apple_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Apple")
                            .font(NunitoFont.semiBold.size(16))
                            .foregroundStyle(.grayScale150)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white, in: .capsule)
                    .overlay(
                        Capsule()
                            .stroke(Color.grayScale40, lineWidth: 1)
                    )
                }
                .disabled(isSigningIn)
            }
           .padding(.bottom, 20)

//            HStack(spacing: 4) {
//                Text("New here?")
//                    .font(ManropeFont.regular.size(12))
//                    .foregroundStyle(.grayScale120)
//
//                Button {
//                    
//                } label: {
//                    Text("Get started instead")
//                        .font(ManropeFont.semiBold.size(12))
//                        .foregroundStyle(rotatedGradient(colors: [Color(hex: "9DCF10"), Color(hex: "6B8E06")], angle: 88))
//                }
//            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .center) {
            if isSigningIn {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(2)

                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .navigationBarBackButtonHidden(true)
    }
}

struct WhosThisFor: View {
    let justmePressed: (() -> Void)?
    let addFamilyPressed: (() -> Void)?
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    init(justmePressed: (() -> Void)? = nil, addFamilyPressed: (() -> Void)? = nil) {
        self.justmePressed = justmePressed
        self.addFamilyPressed = addFamilyPressed
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Hey there! Who’s this for?")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        coordinator.navigateInBottomSheet(.doYouHaveAnInviteCode)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("Is it just you, or your whole IngrediFam — family, friends, anyone you care about?")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {

                Button {
                    justmePressed?()
                } label: {
                    GreenOutlinedCapsule(title: "Just Me")
                }

                Button {
                    addFamilyPressed?()
                } label: {
                    GreenOutlinedCapsule(title: "Add Family")
                }
                
            }
            .padding(.bottom, 20)

            Text("You can always add or edit members later.")
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(.grayScale90)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct AllSetToJoinYourFamily: View {
    let goToHomePressed: () -> Void
    
    init(goToHomePressed: @escaping () -> Void = {}) {
        self.goToHomePressed = goToHomePressed
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("All set to join your family!")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                    .padding(.bottom , 12)

                Text("Welcome to the Patel Family! Your ingredient lists and preferences will now sync automatically.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            Button {
                goToHomePressed()
            } label: {
                GreenCapsule(title: "Go to Home")
                    .frame(width: 156)
            }
            
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct EnterYourInviteCode : View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var isVerifying: Bool = false
    @State var code: [String] = Array(repeating: "", count: 6)
    @State private var isError: Bool = false
    let yesPressed: (() -> Void)?
    let noPressed: (() -> Void)?
    
    init(yesPressed: (() -> Void)? = nil, noPressed: (() -> Void)? = nil) {
        self.yesPressed = yesPressed
        self.noPressed = noPressed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Enter your invite code")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        coordinator.navigateInBottomSheet(.doYouHaveAnInviteCode)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("This connects you to your family or shared\nIngrediCheck space.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)
            
            InviteTextField(code: $code, isError: $isError)
                .padding(.bottom, 12)
            
            if isError {
                Text("We couldn't verify your code. Please try again..")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.red)
                    .padding(.bottom, 44)
            } else {
                Text("You can add this later if you receive one.")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
                    .padding(.bottom, 44)
            }
            
            HStack(spacing: 16) {
                Button {
                    noPressed?()
                } label: {
                    Text("No, continue")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(height: 52)
                        .frame(minWidth: 152)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }
                
                Button {
                    let entered = code.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        // Require a full 6-character code
                        guard entered.count == 6 else {
                            print("[EnterYourInviteCode] Invalid code length: \(entered.count)")
                            await MainActor.run { isError = true }
                            return
                        }
                        
                        await MainActor.run {
                            isVerifying = true
                            isError = false
                        }
                        
                        print("[EnterYourInviteCode] Calling familyStore.join with code=\(entered.uppercased())")
                        await familyStore.join(inviteCode: entered.uppercased())
                        
                        await MainActor.run {
                            isVerifying = false
                            
                            if familyStore.family != nil, familyStore.errorMessage == nil {
                                print("[EnterYourInviteCode] Join success, proceeding to next step")
                                isError = false
                                yesPressed?()
                            } else {
                                print("[EnterYourInviteCode] Join failed, error=\(familyStore.errorMessage ?? "nil")")
                                isError = true
                            }
                        }
                    }
                } label: {
                    ZStack {
                        GreenCapsule(title: isVerifying ? "Verifying..." : "Verify & Continue")
                        if isVerifying {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
                .disabled(isVerifying)
            }
            .padding(.bottom, 20)
            HStack{
                Image("jam-sheld-half")
                    .frame(width: 16, height: 16)
                Text("By continuing, you agree to our Terms & Privacy Policy.")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
        .navigationBarBackButtonHidden(true)
    }

    struct InviteTextField: View {
        @Binding var code: [String]
        @Binding var isError: Bool
        @State private var input: String = ""
        @FocusState private var isFocused: Bool

        private let boxSize = CGSize(width: 44, height: 50)
        private var nextIndex: Int { min(code.firstIndex(where: { $0.isEmpty }) ?? 5, 5) }

        var body: some View {
            ZStack {
                // Hidden TextField that captures all input and backspace behavior
                TextField("", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($isFocused)
                    .onChange(of: input) { newValue in
                        // Allow only A-Z and 0-9, uppercase, and limit to 6 chars
                        let filtered = newValue.filter { $0.isLetter || $0.isNumber }
                        let trimmed = String(filtered.prefix(6))
                        if trimmed != newValue { input = trimmed }

                        let chars = Array(trimmed)
                        for i in 0..<6 {
                            if i < chars.count {
                                code[i] = String(chars[i])
                            } else {
                                code[i] = ""
                            }
                        }
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)

                // Visual OTP boxes
                HStack(spacing: 14) {
                    HStack(spacing: 8) {
                        box(0)
                        box(1)
                        box(2)
                    }

                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(isError && !code.last!.isEmpty ? Color(hex: "FFE2E0") : .grayScale40)
                        .frame(width: 12, height: 2.5)

                    HStack(spacing: 8) {
                        box(3)
                        box(4)
                        box(5)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
            }
            .onAppear {
                // Pre-fill input if parent provided existing code
                input = code.joined().uppercased()
            }
        }

        @ViewBuilder
        private func box(_ index: Int) -> some View {
            ZStack {
                let isFilled = !code[index].isEmpty
                let isActive = isFilled || (isFocused && index == nextIndex)
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(isError && !code.last!.isEmpty ? Color(hex: "FFE2E0") : isActive ? .secondary200 : .grayScale40)
                    .frame(width: boxSize.width, height: boxSize.height)
                    .shadow(color: (isFocused && index == nextIndex) ? Color(hex: "C7C7C7").opacity(0.25) : .clear, radius: 9, x: 0, y: 4)

                // Character for this box (if any)
                Text(code[index])
                    .font(NunitoFont.semiBold.size(22))
                    .foregroundStyle(isError && !code.last!.isEmpty ? Color(hex: "FF1100") : .grayScale150)
            }
        }
    }
}

struct AddMoreMembersMinimal: View {
    let allSetPressed: () -> Void
    let addMorePressed: () -> Void
    
    init(allSetPressed: @escaping () -> Void = {}, addMorePressed: @escaping () -> Void = {}) {
        self.allSetPressed = allSetPressed
        self.addMorePressed = addMorePressed
    }
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Add more members?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("Start by adding their name and a fun avatar—it’ll help us personalize food tips just for them.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                Button {
                    allSetPressed()
                } label: {
                    Text("All Set!")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }
                
                Button {
                    addMorePressed()
                } label: {
                    GreenCapsule(title: "Add Member")
                }

                
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}


struct WouldYouLikeToInvite: View {
    var name: String
    var invitePressed: () -> Void = { }
    var continuePressed: () -> Void = { }
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Would you like to invite \(name) to join IngrediFam?")
                    .font(NunitoFont.bold.size(20))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("No worries if you skip this step. You can share the code with \(name) later too.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                Button {
                    continuePressed()
                } label: {
                    Text("Maybe later")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }
                Button {
                    invitePressed()
                } label: {
                    GreenCapsule(title: "Invite" , icon: "share" ,iconWidth: 12 , iconHeight: 12 ,)
                }
                
               

                
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct WantToAddPreference: View {
    var name: String
    var laterPressed: () -> Void = { }
    var yesPressed: () -> Void = { }
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Do you want to add preferences for \(name)?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("Don't worry, \(name) can add or edit her preferences once she joins Ingredifam")
                    .font(ManropeFont.medium.size(14))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                Button {
                    laterPressed()
                } label: {
                    Text("Later")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }
                
                Button {
                    yesPressed()
                } label: {
                    GreenCapsule(title: "Yes")
                }

                
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

struct YourCurrentAvatar: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @Environment(MemojiStore.self) private var memojiStore
    
    let createNewPressed: () -> Void
    
    init(createNewPressed: @escaping () -> Void = {}) {
        self.createNewPressed = createNewPressed
    }
    
    private var currentMember: FamilyMember? {
        guard let family = familyStore.family else { return nil }
        
        // If a member was selected in SetUpAvatarFor, show that member's avatar
        if let targetMemberId = familyStore.avatarTargetMemberId {
            if targetMemberId == family.selfMember.id {
                return family.selfMember
            } else if let member = family.otherMembers.first(where: { $0.id == targetMemberId }) {
                return member
            }
        }
        
        // Otherwise, default to selfMember
        return family.selfMember
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Show actual member avatar
            if let member = currentMember {
                YourCurrentAvatarView(member: member)
                    .padding(.bottom, 26)
            } else {
                Circle()
                    .fill(Color(hex: "#D9D9D9"))
                    .frame(width: 120, height: 120)
                    .padding(.bottom, 26)
            }
            
            Text("Here's your current avatar. would you like to make a new one?")
                .font(NunitoFont.bold.size(20))
                .multilineTextAlignment(.center)
                .padding(.bottom, 23)
            
            Button {
                // Update display name to current member's name before creating new avatar
                if let member = currentMember {
                    memojiStore.displayName = member.name
                }
                createNewPressed()
            } label: {
                GreenCapsule(title: "Create New")
                    .frame(width: 159)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 64)
        .padding(.top, 40)
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

// MARK: - Your Current Avatar View

/// Large avatar view (120x120) used in YourCurrentAvatar sheet to show the member's current memoji.
struct YourCurrentAvatarView: View {
    let member: FamilyMember
    
    var body: some View {
        // Use centralized MemberAvatar component
        MemberAvatar.large(member: member)
    }
}

struct SetUpAvatarFor: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @Environment(MemojiStore.self) private var memojiStore
    
    private var members: [FamilyMember] {
        guard let family = familyStore.family else { return [] }
        return [family.selfMember] + family.otherMembers
    }
    
    @State private var selectedMember: FamilyMember? = nil
    let nextPressed: () -> Void
    
    init(nextPressed: @escaping () -> Void = {}) {
        self.nextPressed = nextPressed
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            VStack(spacing: 10) {
                Text("Whom do you want to set up\nan avatar for?")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                    .multilineTextAlignment(.center)
                
                Text("Choose a family member to start crafting their avatar")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(members) { member in
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                // Member avatar view that loads actual memoji if available
                                SetUpAvatarMemberView(member: member)
                                    .grayscale(selectedMember?.id == member.id ? 0 : 1)
                                
                                if selectedMember?.id == member.id {
                                    Circle()
                                        .fill(Color(hex: "2C9C3D"))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Circle()
                                                .stroke(lineWidth: 1)
                                                .foregroundStyle(.white)
                                        )
                                        .overlay(
                                            Image("white-rounded-checkmark")
                                        )
                                        .offset(x: 0, y: -3)
                                }
                            }
                            
                            Text(member.name)
                                .font(ManropeFont.regular.size(10))
                                .foregroundStyle(.grayScale150)
                        }
                        .onTapGesture {
                            selectedMember = member
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.vertical, 6)
            }
            
            Button {
                guard let selected = selectedMember else {
                    print("[SetUpAvatarFor] Next tapped with no member selected, ignoring")
                    return
                }
                
                // Update display name for the selected member
                memojiStore.displayName = selected.name
                
                // Remember which member's avatar we are about to generate,
                // so that MeetYourAvatar can upload the image for this member.
                print("[SetUpAvatarFor] Next tapped, setting avatarTargetMemberId=\(selected.id), displayName=\(selected.name)")
                familyStore.avatarTargetMemberId = selected.id
                
                nextPressed()
            } label: {
                GreenCapsule(title: "Next")
                    .frame(width: 180)
            }
            .padding(.bottom, 8)
        }
        
        .padding(.bottom, 53)
        .padding(.top, 40)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(.neutral500)
                .frame(width: 60, height: 4)
                .padding(.top, 11)
            , alignment: .top
        )
    }
}

// MARK: - SetUpAvatar Member Avatar View

/// Avatar view used in SetUpAvatarFor sheet to show actual member memoji avatars.
struct SetUpAvatarMemberView: View {
    let member: FamilyMember
    
    var body: some View {
        // Use centralized MemberAvatar component
        MemberAvatar.custom(member: member, size: 46, imagePadding: 0)
    }
}

#Preview {
    SetUpAvatarFor()
}
