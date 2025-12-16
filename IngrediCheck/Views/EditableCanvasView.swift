//
//  EditableCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar on 15/11/25.
//

import SwiftUI

struct EditableCanvasView: View {
    @EnvironmentObject private var store: Onboarding
    @Environment(\.dismiss) private var dismiss
    @Environment(WebService.self) private var webService
    
    @State private var editingStepId: String? = nil
    @State private var isEditSheetPresented: Bool = false
    @State private var tagBarScrollTarget: UUID? = nil
    @State private var currentEditingSectionIndex: Int = 0
    @State private var isProgrammaticChange: Bool = false
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var currentVersion: Int = 0
    @State private var isLoadingFoodNotes: Bool = false
    
    var body: some View {
        let cards = selectedCards()
        
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // CanvasTagBar
                    CanvasTagBar(
                        store: store,
                        onTapCurrentSection: {
                            // Open edit sheet for current section when tapped
                            openEditSheetForCurrentSection()
                        },
                        scrollTarget: $tagBarScrollTarget,
                        currentBottomSheetRoute: nil
                    )
                    .onChange(of: store.currentSectionIndex) { newIndex in
                        // When section changes via tag bar tap, update/edit sheet for that section
                        if !isProgrammaticChange {
                            // Always update the sheet to show the tapped section's content
                            openEditSheetForSection(at: newIndex)
                        }
                        isProgrammaticChange = false
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    
                    // Selected items scroll view
                    if isLoadingFoodNotes {
                        // Loading state
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.2)
                            Text("Loading your preferences...")
                                .font(ManropeFont.medium.size(16))
                                .foregroundStyle(.grayScale100)
                                .padding(.top, 8)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let cards = cards, !cards.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                    EditableCanvasCard(
                                        chips: card.chips,
                                        sectionedChips: card.sectionedChips,
                                        title: card.title,
                                        iconName: card.icon,
                                        onEdit: {
                                            // Find the section index for this card
                                            if let sectionIndex = store.sections.firstIndex(where: { section in
                                                section.screens.first?.stepId == card.stepId
                                            }) {
                                                currentEditingSectionIndex = sectionIndex
                                                store.currentSectionIndex = sectionIndex
                                            }
                                            editingStepId = card.stepId
                                            isEditSheetPresented = true
                                        }
                                    )
                                    .padding(.top, index == 0 ? 16 : 0)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, isEditSheetPresented ? UIScreen.main.bounds.height * 0.5 : 80)
                        }
                    } else {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer()
                            Text("No selections yet")
                                .font(ManropeFont.regular.size(16))
                                .foregroundStyle(.grayScale100)
                            Text("Complete onboarding to see your preferences here")
                                .font(ManropeFont.regular.size(14))
                                .foregroundStyle(.grayScale130)
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Custom bottom sheet overlay (similar to PersistentBottomSheet)
                if isEditSheetPresented, let stepId = editingStepId {
                    EditSectionBottomSheet(
                        isPresented: $isEditSheetPresented,
                        stepId: stepId,
                        currentSectionIndex: currentEditingSectionIndex,
                        onNext: {
                            handleNextSection()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.neutral500)
                    .frame(width: 60, height: 4)
                    .padding(.top, 12)
                , alignment: .top
            )
        }
        .onAppear {
            // Update completion status for all sections based on their data
            store.updateSectionCompletionStatus()
            
            // Fetch and load food notes data when view appears
            Task {
                await loadFoodNotesFromBackend()
            }
        }
        .onDisappear {
            // Cancel any pending debounce task when view disappears
            debounceTask?.cancel()
            debounceTask = nil
        }
        .onChange(of: store.preferences) { _ in
            // Update completion status whenever preferences change
            store.updateSectionCompletionStatus()
            
            // Debounce API call - cancel previous task and start new one
            debounceTask?.cancel()
            debounceTask = Task {
                do {
                    // Wait 5 seconds
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    
                    // Check if task was cancelled
                    try Task.checkCancellation()
                    
                    // Build content structure and call API
                    await updateFoodNotes()
                } catch {
                    // Task was cancelled or sleep interrupted - ignore
                    if !(error is CancellationError) {
                        print("[EditableCanvasView] Debounce task error: \(error)")
                    }
                }
            }
        }
    }
    
    private func icon(for stepId: String) -> String {
        if let step = store.step(for: stepId),
           let icon = step.header.iconURL,
           icon.isEmpty == false {
            return icon
        }
        return "allergies"
    }
    
    private func chips(for stepId: String) -> [ChipsModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        guard let value = store.preferences.sections[sectionName],
              case .list(let items) = value else {
            return nil
        }
        
        // Get icons from step options
        let options = step.content.options ?? []
        return items.compactMap { itemName -> ChipsModel? in
            if let option = options.first(where: { $0.name == itemName }) {
                return ChipsModel(name: option.name, icon: option.icon)
            }
            return ChipsModel(name: itemName, icon: nil)
        }
    }
    
    private func sectionedChips(for stepId: String) -> [SectionedChipModel]? {
        guard let step = store.step(for: stepId) else { return nil }
        let sectionName = step.header.name
        
        guard let value = store.preferences.sections[sectionName],
              case .nested(let nestedDict) = value else {
            return nil
        }
        
        // Type-2 steps use subSteps, type-3 steps use regions. Handle both.
        var sections: [SectionedChipModel] = []
        
        if let subSteps = step.content.subSteps {
            // MARK: Type-2 (Avoid / Lifestyle / Nutrition-style)
            for subStep in subSteps {
                guard let selectedItems = nestedDict[subStep.title],
                      !selectedItems.isEmpty else {
                    continue
                }
                
                // Map selected items to ChipsModel with icons
                let selectedChips: [ChipsModel] = selectedItems.compactMap { itemName in
                    if let option = subStep.options?.first(where: { $0.name == itemName }) {
                        return ChipsModel(name: option.name, icon: option.icon)
                    }
                    return ChipsModel(name: itemName, icon: nil)
                }
                
                if !selectedChips.isEmpty {
                    sections.append(
                        SectionedChipModel(
                            title: subStep.title,
                            subtitle: subStep.description,
                            chips: selectedChips
                        )
                    )
                }
            }
        } else if let regions = step.content.regions {
            // MARK: Type-3 (Region-style)
            for region in regions {
                guard let selectedItems = nestedDict[region.name],
                      !selectedItems.isEmpty else {
                    continue
                }
                
                let selectedChips: [ChipsModel] = selectedItems.compactMap { itemName in
                    if let option = region.subRegions.first(where: { $0.name == itemName }) {
                        return ChipsModel(name: option.name, icon: option.icon)
                    }
                    return ChipsModel(name: itemName, icon: nil)
                }
                
                if !selectedChips.isEmpty {
                    sections.append(
                        SectionedChipModel(
                            title: region.name,
                            subtitle: nil,
                            chips: selectedChips
                        )
                    )
                }
            }
        }
        
        return sections.isEmpty ? nil : sections
    }
    
    private func selectedCards() -> [EditableCanvasCardModel]? {
        var cards: [EditableCanvasCardModel] = []
        
        for section in store.sections {
            guard let stepId = section.screens.first?.stepId else { continue }
            let chips = chips(for: stepId)
            let groupedChips = sectionedChips(for: stepId)
            
            if chips != nil || groupedChips != nil {
                cards.append(
                    EditableCanvasCardModel(
                        id: section.id,
                        title: section.name,
                        icon: icon(for: stepId),
                        stepId: stepId,
                        chips: chips,
                        sectionedChips: groupedChips
                    )
                )
            }
        }
        
        return cards.isEmpty ? nil : cards
    }
    
    private func openEditSheetForCurrentSection() {
        if let stepId = store.currentSection.screens.first?.stepId {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentEditingSectionIndex = store.currentSectionIndex
                editingStepId = stepId
                isEditSheetPresented = true
            }
        }
    }
    
    private func openEditSheetForSection(at index: Int) {
        guard store.sections.indices.contains(index),
              let stepId = store.sections[index].screens.first?.stepId else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentEditingSectionIndex = index
            editingStepId = stepId
            isEditSheetPresented = true
        }
    }
    
    private func handleNextSection() {
        // Move to next section
        if currentEditingSectionIndex < store.sections.count - 1 {
            let nextIndex = currentEditingSectionIndex + 1
            if let nextStepId = store.sections[nextIndex].screens.first?.stepId {
                isProgrammaticChange = true
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentEditingSectionIndex = nextIndex
                    store.currentSectionIndex = nextIndex
                    editingStepId = nextStepId
                }
                // Sheet will update automatically via editingStepId change
            }
        } else {
            // Last section, close the sheet
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditSheetPresented = false
            }
        }
    }
    
    // MARK: - Food Notes API Integration
    
    @MainActor
    private func loadFoodNotesFromBackend() async {
        print("[EditableCanvasView] loadFoodNotesFromBackend: Starting to load food notes from backend")
        
        // Show loading indicator
        isLoadingFoodNotes = true
        
        do {
            if let response = try await webService.fetchFoodNotes() {
                print("[EditableCanvasView] loadFoodNotesFromBackend: ✅ Received food notes data")
                print("[EditableCanvasView] loadFoodNotesFromBackend: Version: \(response.version), UpdatedAt: \(response.updatedAt)")
                print("[EditableCanvasView] loadFoodNotesFromBackend: Content keys: \(response.content.keys.joined(separator: ", "))")
                
                // Update version
                currentVersion = response.version
                
                // Convert content structure to Preferences format
                await convertContentToPreferences(content: response.content)
                
                // Update completion status after loading
                store.updateSectionCompletionStatus()
                
                print("[EditableCanvasView] loadFoodNotesFromBackend: ✅ Successfully loaded and applied food notes data")
            } else {
                // No food notes exist yet, start with version 0
                currentVersion = 0
                print("[EditableCanvasView] loadFoodNotesFromBackend: No existing food notes found, starting with version 0")
            }
        } catch let error as NetworkError {
            // If GET endpoint doesn't exist (404) or other errors, start with version 0
            // The version will be corrected on first update attempt via error parsing
            if case .notFound = error {
                currentVersion = 0
                print("[EditableCanvasView] loadFoodNotesFromBackend: GET endpoint not available (404), will detect version on first update")
            } else {
                currentVersion = 0
                print("[EditableCanvasView] loadFoodNotesFromBackend: ❌ Failed to load food notes: \(error)")
            }
        } catch {
            // If fetch fails for any other reason, start with version 0
            currentVersion = 0
            print("[EditableCanvasView] loadFoodNotesFromBackend: ❌ Failed to load food notes: \(error.localizedDescription)")
        }
        
        // Hide loading indicator
        isLoadingFoodNotes = false
    }
    
    @MainActor
    private func convertContentToPreferences(content: [String: Any]) async {
        print("[EditableCanvasView] convertContentToPreferences: Converting content to preferences format")
        
        // Iterate through content keys (which are step IDs)
        for (stepId, stepContent) in content {
            print("[EditableCanvasView] convertContentToPreferences: Processing stepId: \(stepId)")
            
            // Find the step by ID to get the section name
            guard let step = store.dynamicSteps.first(where: { $0.id == stepId }) else {
                print("[EditableCanvasView] convertContentToPreferences: ⚠️ Step not found for stepId: \(stepId), skipping")
                continue
            }
            
            let sectionName = step.header.name
            print("[EditableCanvasView] convertContentToPreferences: Found step '\(sectionName)' for stepId: \(stepId)")
            
            // Check if content is an array (type-1) or nested object (type-2 or type-3)
            if let itemsArray = stepContent as? [[String: Any]] {
                // Type-1: Simple list
                print("[EditableCanvasView] convertContentToPreferences: Type-1 list with \(itemsArray.count) items")
                let itemNames = itemsArray.compactMap { item -> String? in
                    if let name = item["name"] as? String {
                        return name
                    }
                    return nil
                }
                
                if !itemNames.isEmpty {
                    store.preferences.sections[sectionName] = .list(itemNames)
                    print("[EditableCanvasView] convertContentToPreferences: ✅ Set \(sectionName) as list with items: \(itemNames.joined(separator: ", "))")
                }
            } else if let nestedDict = stepContent as? [String: Any] {
                // Type-2 or Type-3: Nested structure
                print("[EditableCanvasView] convertContentToPreferences: Nested structure with keys: \(nestedDict.keys.joined(separator: ", "))")
                
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
                            print("[EditableCanvasView] convertContentToPreferences: ✅ Set nested key '\(nestedKey)' with items: \(itemNames.joined(separator: ", "))")
                        }
                    }
                }
                
                if !preferencesNestedDict.isEmpty {
                    store.preferences.sections[sectionName] = .nested(preferencesNestedDict)
                    print("[EditableCanvasView] convertContentToPreferences: ✅ Set \(sectionName) as nested with \(preferencesNestedDict.count) sub-sections")
                }
            } else {
                print("[EditableCanvasView] convertContentToPreferences: ⚠️ Unknown content format for stepId: \(stepId)")
            }
        }
        
        print("[EditableCanvasView] convertContentToPreferences: ✅ Conversion complete")
    }
    
    @MainActor
    private func updateFoodNotes() async {
        // Build content structure dynamically from preferences
        var content: [String: Any] = [:]
        
        // Iterate through all dynamic steps to build content
        for step in store.dynamicSteps {
            let sectionName = step.header.name
            
            guard let preferenceValue = store.preferences.sections[sectionName] else {
                continue
            }
            
            switch preferenceValue {
            case .list(let items):
                // Simple list - convert to array of objects with iconName and name
                let itemsArray = items.compactMap { itemName -> [String: String]? in
                    // Find icon from step options
                    let icon = step.content.options?.first(where: { $0.name == itemName })?.icon ?? ""
                    return [
                        "iconName": icon,
                        "name": itemName
                    ]
                }
                
                if !itemsArray.isEmpty {
                    // Use step id as key (lowercased) for the content
                    content[step.id] = itemsArray
                }
                
            case .nested(let nestedDict):
                // Nested structure - for type-2 steps (Avoid, LifeStyle, Nutrition)
                var nestedContent: [String: Any] = [:]
                
                if let subSteps = step.content.subSteps {
                    for subStep in subSteps {
                        if let items = nestedDict[subStep.title], !items.isEmpty {
                            let itemsArray = items.compactMap { itemName -> [String: String]? in
                                let icon = subStep.options?.first(where: { $0.name == itemName })?.icon ?? ""
                                return [
                                    "iconName": icon,
                                    "name": itemName
                                ]
                            }
                            
                            if !itemsArray.isEmpty {
                                nestedContent[subStep.title] = itemsArray
                            }
                        }
                    }
                } else if step.type == .type3 {
                    // Type-3 (Region) - regions with subRegions
                    for (regionName, items) in nestedDict {
                        if !items.isEmpty {
                            let itemsArray = items.compactMap { itemName -> [String: String]? in
                                // Find icon from regions structure
                                var icon = ""
                                if let region = step.content.regions?.first(where: { $0.name == regionName }) {
                                    icon = region.subRegions.first(where: { $0.name == itemName })?.icon ?? ""
                                }
                                return [
                                    "iconName": icon,
                                    "name": itemName
                                ]
                            }
                            
                            if !itemsArray.isEmpty {
                                nestedContent[regionName] = itemsArray
                            }
                        }
                    }
                }
                
                if !nestedContent.isEmpty {
                    content[step.id] = nestedContent
                }
            }
        }
        
        // Only call API if content is not empty
        guard !content.isEmpty else {
            print("[EditableCanvasView] updateFoodNotes: Content is empty, skipping API call")
            return
        }
        
        do {
            print("[EditableCanvasView] updateFoodNotes: Calling API with version \(currentVersion)")
            print("[EditableCanvasView] updateFoodNotes: Content keys: \(content.keys.joined(separator: ", "))")
            
            let response = try await webService.updateFoodNotes(content: content, version: currentVersion)
            
            // Update version from response
            await MainActor.run {
                currentVersion = response.version
            }
            
            print("[EditableCanvasView] updateFoodNotes: ✅ Success! Updated version to \(response.version), updatedAt: \(response.updatedAt)")
        } catch let error as WebService.VersionMismatchError {
            // Handle version mismatch - update to current version and retry
            print("[EditableCanvasView] updateFoodNotes: ⚠️ Version mismatch detected. Expected: \(error.expectedVersion), Current on server: \(error.currentVersion)")
            
            await MainActor.run {
                currentVersion = error.currentVersion
            }
            
            // Retry with the correct version
            do {
                print("[EditableCanvasView] updateFoodNotes: Retrying with version \(currentVersion)")
                let response = try await webService.updateFoodNotes(content: content, version: currentVersion)
                
                await MainActor.run {
                    currentVersion = response.version
                }
                
                print("[EditableCanvasView] updateFoodNotes: ✅ Success after retry! Updated version to \(response.version), updatedAt: \(response.updatedAt)")
            } catch {
                print("[EditableCanvasView] updateFoodNotes: ❌ Failed on retry: \(error.localizedDescription)")
            }
        } catch {
            if let networkError = error as? NetworkError {
                switch networkError {
                case .invalidResponse(let statusCode):
                    print("[EditableCanvasView] updateFoodNotes: ❌ Failed - Invalid response: \(statusCode)")
                case .authError:
                    print("[EditableCanvasView] updateFoodNotes: ❌ Failed - Authentication error")
                case .decodingError:
                    print("[EditableCanvasView] updateFoodNotes: ❌ Failed - Decoding error")
                case .badUrl:
                    print("[EditableCanvasView] updateFoodNotes: ❌ Failed - Bad URL")
                case .notFound(let message):
                    print("[EditableCanvasView] updateFoodNotes: ❌ Failed - Not found: \(message)")
                }
            } else {
                print("[EditableCanvasView] updateFoodNotes: ❌ Failed - Error: \(error.localizedDescription)")
            }
        }
    }
}

struct EditableCanvasCardModel: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let stepId: String
    let chips: [ChipsModel]?
    let sectionedChips: [SectionedChipModel]?
}

struct EditableCanvasCard: View {
    var chips: [ChipsModel]? = nil
    var sectionedChips: [SectionedChipModel]? = nil
    var title: String = "Allergies"
    var iconName: String = "allergies"
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(iconName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.grayScale110)
                        .frame(width: 18, height: 18)
                    
                    Text(title.capitalized)
                        .font(NunitoFont.semiBold.size(14))
                        .foregroundStyle(.grayScale110)
                }
                .fontWeight(.semibold)
                
                Spacer()
                
                // Edit button
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image("pen-line")
                                .resizable()
                                .frame(width: 14, height: 14)
                                
                            Text("Edit")
                                .font(NunitoFont.medium.size(14))
                                .foregroundStyle(.grayScale130)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .foregroundStyle(.grayScale30)
                        )
                    }
                }
            }
            
            VStack(alignment: .leading) {
                if let sectionedChips = sectionedChips {
                    ForEach(sectionedChips) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(ManropeFont.semiBold.size(12))
                                .foregroundStyle(.grayScale150)
                            
                            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                ForEach(section.chips) { chip in
                                    IngredientsChips(
                                        title: chip.name,
                                        bgColor: .secondary200,
                                        image: chip.icon,
                                        outlined: false
                                    )
                                }
                            }
                        }
                    }
                } else if let chips = chips {
                    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(chips, id: \.id) { chip in
                            IngredientsChips(
                                title: chip.name,
                                bgColor: .secondary200,
                                image: chip.icon,
                                outlined: false
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
                .shadow(color: Color(hex: "ECECEC"), radius: 9, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

// MARK: - Edit Section Bottom Sheet

struct EditSectionBottomSheet: View {
    @EnvironmentObject private var store: Onboarding
    @Binding var isPresented: Bool
    
    let stepId: String
    let currentSectionIndex: Int
    var onNext: (() -> Void)? = nil
    
    private var isLastSection: Bool {
        currentSectionIndex >= store.sections.count - 1
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let step = store.step(for: stepId) {
                DynamicOnboardingStepView(
                    step: step,
                    flowType: store.onboardingFlowtype,
                    preferences: $store.preferences
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .transition(.opacity)
            }
            
            // Next button (GreenCircle)
            if let onNext = onNext {
                Button(action: onNext) {
                    GreenCircle()
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.white)
        .cornerRadius(36, corners: [.topLeft, .topRight])
        .shadow(radius: 27.5)
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.2), value: stepId)
        .onChange(of: stepId) { _ in
            // Update completion status when switching sections
            store.updateSectionCompletionStatus()
        }
        .onChange(of: isPresented) { newValue in
            // Update completion status when sheet is dismissed
            if !newValue {
                store.updateSectionCompletionStatus()
            }
        }
    }
}

#Preview {
    EditableCanvasView()
        .environmentObject(Onboarding(onboardingFlowtype: .individual))
}

