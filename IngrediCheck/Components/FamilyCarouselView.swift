//
//  FamilyCarouselView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 01/10/25.
//

import SwiftUI

struct FamilyCarouselView: View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(WebService.self) private var webService
    @EnvironmentObject private var store: Onboarding
    
    @State var selectedFamilyMember: UserModel? = UserModel(familyMemberName: "Everyone", familyMemberImage: "Everyone", backgroundColor: .clear)
    @State private var isLoadingMemberFoodNotes: Bool = false
    
    // Convert FamilyMember objects to UserModel format
    private var familyMembersList: [UserModel] {
        var members: [UserModel] = []
        
        // Always include "Everyone" as the first option
        members.append(
            UserModel(
                id: "everyone",
                familyMemberName: "Everyone",
                familyMemberImage: "Everyone",
                backgroundColor: .clear
            )
        )
        
        // Add actual family members from FamilyStore
        if let family = familyStore.family {
            // Add self member
            members.append(
                UserModel(
                    id: family.selfMember.id.uuidString,
                    familyMemberName: family.selfMember.name,
                    familyMemberImage: family.selfMember.name, // Use name as image identifier
                    backgroundColor: Color(hex: family.selfMember.color)
                )
            )
            
            // Add other members
            for otherMember in family.otherMembers {
                members.append(
                    UserModel(
                        id: otherMember.id.uuidString,
                        familyMemberName: otherMember.name,
                        familyMemberImage: otherMember.name, // Use name as image identifier
                        backgroundColor: Color(hex: otherMember.color)
                    )
                )
            }
        }
        
        return members
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(familyMembersList, id: \.id) { ele in
                    circleImage(
                        image: ele.image,
                        name: ele.name,
                        color: ele.backgroundColor ?? .clear,
                        isSelected: ele.id == selectedFamilyMember?.id
                    )
                    .onTapGesture {
                        Task {
                            await selectFamilyMember(ele: ele)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize selection to "Everyone" if not already set
            if selectedFamilyMember == nil {
                selectedFamilyMember = UserModel(
                    id: "everyone",
                    familyMemberName: "Everyone",
                    familyMemberImage: "Everyone",
                    backgroundColor: .clear
                )
                
                // Initial load for family-level notes
                Task {
                    await loadFoodNotesForSelection(memberId: nil)
                }
            }
        }
    }
    
    @MainActor
    func selectFamilyMember(ele: UserModel) async {
        print("[FamilyCarouselView] selectFamilyMember: Tapped member name=\(ele.name), id=\(ele.id)")
        selectedFamilyMember = ele
        
        // "everyone" is our sentinel ID for the family-level note
        let memberId: String? = (ele.id == "everyone") ? nil : ele.id
        
        // Keep FamilyStore in sync so other components (like EditableCanvasView)
        // know whether we are editing at family level or for a specific member.
        if let memberId, let uuid = UUID(uuidString: memberId) {
            print("[FamilyCarouselView] selectFamilyMember: Setting FamilyStore.selectedMemberId=\(uuid)")
            familyStore.selectedMemberId = uuid
        } else {
            print("[FamilyCarouselView] selectFamilyMember: Setting FamilyStore.selectedMemberId=nil (Everyone)")
            familyStore.selectedMemberId = nil
        }
        
        await loadFoodNotesForSelection(memberId: memberId)
    }
    
    // MARK: - Member-specific Food Notes Integration
    
    @MainActor
    private func loadFoodNotesForSelection(memberId: String?) async {
        isLoadingMemberFoodNotes = true
        defer { isLoadingMemberFoodNotes = false }
        
        do {
            if let memberId {
                print("[FamilyCarouselView] loadFoodNotesForSelection: Fetching member food notes for memberId=\(memberId)")
                if let response = try await webService.fetchMemberFoodNotes(memberId: memberId) {
                    print("[FamilyCarouselView] loadFoodNotesForSelection: ✅ Received member food notes version=\(response.version), updatedAt=\(response.updatedAt)")
                    print("[FamilyCarouselView] loadFoodNotesForSelection: Content keys: \(Array(response.content.keys))")
                    
                    // Reset preferences and apply member-specific content
                    store.preferences = Preferences()
                    await convertContentToPreferencesFromContent(content: response.content)
                    store.updateSectionCompletionStatus()
                    
                    print("[FamilyCarouselView] loadFoodNotesForSelection: ✅ Applied member-specific preferences")
                } else {
                    print("[FamilyCarouselView] loadFoodNotesForSelection: No member food notes found, clearing preferences")
                    store.preferences = Preferences()
                    store.updateSectionCompletionStatus()
                }
            } else {
                print("[FamilyCarouselView] loadFoodNotesForSelection: Fetching family-level food notes")
                if let response = try await webService.fetchFoodNotes() {
                    print("[FamilyCarouselView] loadFoodNotesForSelection: ✅ Received family food notes version=\(response.version), updatedAt=\(response.updatedAt)")
                    print("[FamilyCarouselView] loadFoodNotesForSelection: Content keys: \(Array(response.content.keys))")
                    
                    // Reset preferences and apply family-level content
                    store.preferences = Preferences()
                    await convertContentToPreferencesFromContent(content: response.content)
                    store.updateSectionCompletionStatus()
                    
                    print("[FamilyCarouselView] loadFoodNotesForSelection: ✅ Applied family-level preferences")
                } else {
                    print("[FamilyCarouselView] loadFoodNotesForSelection: No family food notes found, clearing preferences")
                    store.preferences = Preferences()
                    store.updateSectionCompletionStatus()
                }
            }
        } catch {
            print("[FamilyCarouselView] loadFoodNotesForSelection: ❌ Failed to load food notes: \(error.localizedDescription)")
        }
    }
    
    /// Local copy of the conversion logic used by the editable canvas to
    /// translate backend food-notes `content` into `Preferences`.
    @MainActor
    private func convertContentToPreferencesFromContent(content: [String: Any]) async {
        print("[FamilyCarouselView] convertContentToPreferencesFromContent: Converting content to preferences format")
        
        // Iterate through content keys (which are step IDs)
        for (stepId, stepContent) in content {
            print("[FamilyCarouselView] convertContentToPreferencesFromContent: Processing stepId: \(stepId)")
            
            // Find the step by ID to get the section name
            guard let step = store.dynamicSteps.first(where: { $0.id == stepId }) else {
                print("[FamilyCarouselView] convertContentToPreferencesFromContent: ⚠️ Step not found for stepId: \(stepId), skipping")
                continue
            }
            
            let sectionName = step.header.name
            print("[FamilyCarouselView] convertContentToPreferencesFromContent: Found step '\(sectionName)' for stepId: \(stepId)")
            
            // Check if content is an array (type-1) or nested object (type-2 or type-3)
            if let itemsArray = stepContent as? [[String: Any]] {
                // Type-1: Simple list
                print("[FamilyCarouselView] convertContentToPreferencesFromContent: Type-1 list with \(itemsArray.count) items")
                let itemNames = itemsArray.compactMap { item -> String? in
                    if let name = item["name"] as? String {
                        return name
                    }
                    return nil
                }
                
                if !itemNames.isEmpty {
                    store.preferences.sections[sectionName] = .list(itemNames)
                    print("[FamilyCarouselView] convertContentToPreferencesFromContent: ✅ Set \(sectionName) as list with items: \(itemNames)")
                }
            } else if let nestedDict = stepContent as? [String: Any] {
                // Type-2 or Type-3: Nested structure
                print("[FamilyCarouselView] convertContentToPreferencesFromContent: Nested structure with keys: \(Array(nestedDict.keys))")
                
                var preferencesNestedDict: [String: [String]] = [:]
                
                for (nestedKey, nestedValue) in nestedDict {
                    if let itemsArray = nestedValue as? [[String: Any]] {
                        let itemNames = itemsArray.compactMap { item -> String? in
                            if let name = item["name"] as? String {
                                return name
                            }
                            return nil
                        }
                        
                        if !itemNames.isEmpty {
                            preferencesNestedDict[nestedKey] = itemNames
                            print("[FamilyCarouselView] convertContentToPreferencesFromContent: ✅ Set nested key '\(nestedKey)' with items: \(itemNames)")
                        }
                    }
                }
                
                if !preferencesNestedDict.isEmpty {
                    store.preferences.sections[sectionName] = .nested(preferencesNestedDict)
                    print("[FamilyCarouselView] convertContentToPreferencesFromContent: ✅ Set \(sectionName) as nested with \(preferencesNestedDict.count) sub-sections")
                }
            } else {
                print("[FamilyCarouselView] convertContentToPreferencesFromContent: ⚠️ Unknown content format for stepId: \(stepId)")
            }
        }
        
        print("[FamilyCarouselView] convertContentToPreferencesFromContent: ✅ Conversion complete")
    }
}

struct circleImage: View {

    let image: String
    let name: String?
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            if name == "Everyone" {
                ZStack {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color(hex: "91B640"), lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                    
                    Circle()
                        .frame(width: 46, height: 46)
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "FFC552"), Color(hex: "FFAA28")], startPoint: .top, endPoint: .bottom)
                        )
                        .overlay(
                            Image(image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                        )
                }
            } else {
                ZStack {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color(hex: "91B640"), lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                    
                    Circle()
                        .frame(width: 46, height: 46)
                        .foregroundStyle(color)
                        .overlay(
                            Text(String((name ?? "").prefix(1)))
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
            
            if let name = name {
                Text(name)
                    .font(ManropeFont.regular.size(10))
                    .foregroundStyle(isSelected ? Color(hex: "91B640") : .grayScale130)
            }
        }
    }
}

#Preview {
    FamilyCarouselView()
        .environment(FamilyStore())
}
