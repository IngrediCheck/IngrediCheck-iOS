//
//  EditableCanvasView.swift
//  IngrediCheck
//
//  Legacy wrapper retained for compatibility.
//

import SwiftUI

struct EditableCanvasView: View {
    let targetSectionName: String?
    let onBack: (() -> Void)?
    let titleOverride: String?
    let showBackButton: Bool

    init(
        targetSectionName: String? = nil,
        titleOverride: String? = nil,
        showBackButton: Bool = true,
        onBack: (() -> Void)? = nil
    ) {
        self.targetSectionName = targetSectionName
        self.titleOverride = titleOverride
        self.showBackButton = showBackButton
        self.onBack = onBack
    }

    var body: some View {
        UnifiedCanvasView(
            mode: .editing,
            targetSectionName: targetSectionName,
            titleOverride: titleOverride,
            showBackButton: showBackButton,
            onDismiss: onBack
        )
    }
}

struct EditableCanvasCard: View {
    var chips: [ChipsModel]? = nil
    var sectionedChips: [SectionedChipModel]? = nil
    var title: String = "Allergies"
    var iconName: String = "allergies"
    var onEdit: (() -> Void)? = nil
    var itemMemberAssociations: [String: [String: [String]]] = [:]
    var showFamilyIcons: Bool = true
    var activeMemberId: UUID? = nil

    private var isEmptyState: Bool {
        let hasSectioned = sectionedChips?.isEmpty == false
        let hasChips = chips?.isEmpty == false
        return !hasSectioned && !hasChips
    }

    private func memberIdentifiers(for itemName: String) -> [String] {
        guard let memberIds = itemMemberAssociations[title]?[itemName] else {
            return []
        }
        if let activeMemberId {
            return [activeMemberId.uuidString]
        }
        return memberIds
    }

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

                Spacer()

                if let onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image("pen-line")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundStyle(.grayScale110)
                                .frame(width: 14, height: 14)

                            Text("Edit")
                                .font(NunitoFont.medium.size(14))
                                .foregroundStyle(.grayScale110)
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
                if isEmptyState {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.grayScale30.opacity(0.5))
                                .frame(width: 40, height: 40)
                            Image("edit-pen")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.grayScale80)
                        }
                        .padding(.top, 8)

                        Text("Nothing added yet")
                            .font(NunitoFont.semiBold.size(14))
                            .foregroundStyle(.grayScale100)

                        Text("You can add details anytime by tapping Edit.")
                            .font(NunitoFont.regular.size(10))
                            .foregroundStyle(.grayScale100)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                } else if let sectionedChips {
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
                                        familyList: showFamilyIcons ? memberIdentifiers(for: chip.name) : [],
                                        outlined: false
                                    )
                                }
                            }
                        }
                    }
                } else if let chips {
                    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(chips, id: \.id) { chip in
                            IngredientsChips(
                                title: chip.name,
                                bgColor: .secondary200,
                                image: chip.icon,
                                familyList: showFamilyIcons ? memberIdentifiers(for: chip.name) : [],
                                outlined: false
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isEmptyState ? 8 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

struct MiscNotesCard: View {
    let notes: [String]
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .foregroundStyle(.grayScale110)
                        .frame(width: 16, height: 18)

                    Text("Notes")
                        .font(NunitoFont.semiBold.size(14))
                        .foregroundStyle(.grayScale110)
                }

                Spacer()

                if let onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .resizable()
                                .foregroundStyle(.grayScale110)
                                .frame(width: 14, height: 14)

                            Text("Chat")
                                .font(NunitoFont.medium.size(14))
                                .foregroundStyle(.grayScale110)
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

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(NunitoFont.regular.size(14))
                            .foregroundStyle(.grayScale100)
                        Text(note)
                            .font(NunitoFont.regular.size(14))
                            .foregroundStyle(.grayScale100)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 0.25)
                .foregroundStyle(.grayScale60)
        )
    }
}

#Preview {
    let webService = WebService()
    let onboarding = Onboarding(onboardingFlowtype: .individual)
    let foodNotesStore = FoodNotesStore(webService: webService, onboardingStore: onboarding)

    EditableCanvasView()
        .environmentObject(onboarding)
        .environment(webService)
        .environment(foodNotesStore)
}
