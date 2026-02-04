//
//  GenerateAvatar.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//

import SwiftUI

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
                                    
                                    Text(Microcopy.formatted(Microcopy.Key.Avatar.Generate.title, memojiStore.displayName ?? ""))
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
                                    
                                    Microcopy.text(Microcopy.Key.Avatar.Generate.selected)
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
//            .overlay(
//                RoundedRectangle(cornerRadius: 4)
//                    .fill(.neutral500)
//                    .frame(width: 60, height: 4)
//                    .padding(.top, 11)
//                , alignment: .top
//            )
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
