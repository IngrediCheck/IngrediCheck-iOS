//
//  DetailedAISummary.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 31/10/25.
//

import SwiftUI
import UIKit

struct DashedLine: View {
    var color: Color = .gray.opacity(0.4)
    var dash: [CGFloat] = [8]
    var lineWidth: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
        }
        .frame(height: lineWidth)
    }
}



struct DetailedAISummary: View {
    private let sections: [AISummarySectionItem] = AISummarySectionItem.sample

    var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                header
                
                AIPill()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        SnapshotCard()
                        
                        HStack {
                            Circle()
                                .fill(Color(hex: "FDF6E7"))
                                .frame(width: 40, height: 40)
                            
                            DashedLine()
                            
                            Circle()
                                .fill(Color(hex: "FDF6E7"))
                                .frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, -20)
                        
                        ForEach(sections) { section in
                            AISummarySectionRow(section: section, isLast: section == sections.last!)
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 18)
                        .padding(.bottom, 20)
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 28))
                }
                
                GradientButton(title: "Next") {}
                    .padding(.top, 8)
            }
            .padding(20)
        .background(Color(hex: "FDF6E7"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All set! Here’s Your Personal\nFood Map")
                .font(NunitoFont.bold.size(22))
                .foregroundStyle(.grayScale150)

            Text("A quick peek into what makes your eating style unique!")
                .font(ManropeFont.regular.size(14))
                .foregroundStyle(.grayScale140)
        }
    }
}

#Preview {
    DetailedAISummary()
}

// MARK: - Models

struct AISummarySectionItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let iconAssetName: String?
    let bulletPoints: [String]
}

extension AISummarySectionItem {
    static let sample: [AISummarySectionItem] = [
        .init(
            title: "Allergy Alerts",
            iconAssetName: "allergy-alerts",
            bulletPoints: [
                "Avoids Peanuts, Shellfish, Eggs, Wheat, Molluscs, and Artificial Flavours",
                "Meals should be free from common allergens and any artificial flavor enhancers."
            ]
        ),
        .init(
            title: "Intolerances",
            iconAssetName: "intolerances",
            bulletPoints: [
                "Sensitive to Lactose, Fructose, Gluten, and FODMAPs",
                "Prefers easily digestible, gut‑friendly food options with minimal irritants."
            ]
        ),
        .init(
            title: "Health Conditions",
            iconAssetName: "health-conditions",
            bulletPoints: [
                "Focused on managing Diabetes, Hypertension, PKU, Heart Health, and Celiac Disease",
                "Seeks nutrient‑balanced meals with controlled sugars, sodium, and saturated fats."
            ]
        ),
        .init(
            title: "Life Stage",
            iconAssetName: "life-stage",
            bulletPoints: [
                "Chooses options suitable for Kids/Babies and Seniors",
                "Prefers gentle, nutrient‑rich, and age‑appropriate foods for all life stages."
            ]
        ),
        .init(
            title: "Region & Traditions",
            iconAssetName: "region-traditions",
            bulletPoints: [
                "Inspired by Indian & South Asian and Hindu food traditions",
                "Likely prefers vegetarian‑friendly and culturally aligned meal patterns."
            ]
        ),
        .init(
            title: "Avoid",
            iconAssetName: "avoid",
            bulletPoints: [
                "Oils & Fats: No hydrogenated oils, trans fats, corn syrup, or palm oil",
                "Animal‑Based: Avoids pork, beef, seafood, gelatin, and lard",
                "Stimulants & Substances: Avoids alcohol",
                "Additives & Sweeteners: No MSG or artificial sweeteners (even stevia/monk fruit)",
                "Plant‑Based Restrictions: Avoids garlic and onion",
                "Meals should be clean‑label, natural, and free from animal‑based or processed components."
            ]
        ),
        .init(
            title: "Lifestyle",
            iconAssetName: "lifestyle",
            bulletPoints: [
                "Plant & Balance: Prefers vegetarian or reducetarian approach",
                "Quality & Source: Chooses organic and seasonal produce",
                "Sustainable Living: Practices zero‑waste and avoids excessive packaging"
            ]
        ),
        .init(
            title: "Nutrition",
            iconAssetName: "nutritions",
            bulletPoints: [
                "Prioritizes high‑protein, low‑fat foods",
                "Reinforces organic, seasonal, and sustainable sourcing principles for optimal nutrition."
            ]
        ),
        .init(
            title: "Ethical",
            iconAssetName: "ethical",
            bulletPoints: [
                "Focused on animal welfare and low‑carbon footprint foods",
                "Ethically aligned dietary patterns that respect both nature and life."
            ]
        ),
        .init(
            title: "Taste",
            iconAssetName: "taste",
            bulletPoints: [
                "Prefers less sweet foods",
                "Avoids slimy textures, favoring balanced flavors and satisfying textures."
            ]
        ),
        .init(
            title: "Other preferences you’ve shared",
            iconAssetName: "other-preferences",
            bulletPoints: [
                "Prefer home‑cooked meals and try to avoid overly processed foods",
                "Exploring more plant‑based options but still enjoy flexibility when eating out",
                "Focus on gut‑friendly meals and natural ingredients",
                "Like dishes that are simple, quick to make, yet nutritious and satisfying",
                "Enjoy trying new ingredients or regional flavors that fit your diet."
            ]
        )
    ]
}

// MARK: - Components

private struct AIPill: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(.summarise)
                .resizable()
                .frame(width: 28, height: 28)
            
            
            Text("Summarized with AI")
                .font(ManropeFont.semiBold.size(14))
                .foregroundStyle(.grayScale150)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                        .init(color: Color(hex: "91B640"), location: 0.0),
                                        .init(color: Color(hex: "FFFAED"), location: 1.25)
                                    ]),
                                startPoint: .leading,
                                endPoint: .trailing)
                        )
                        .frame(height: 1.7)
                        .offset(y: 2)
                    
                    , alignment: .bottom
                )
        }
    }
}

private struct SnapshotCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Dietary Snapshot")
                .font(ManropeFont.bold.size(16))
                .foregroundStyle(.grayScale150)

            Group {
                Text("You eat with intention and care, balancing health, ethics, and the planet beautifully. Your meals stay free from major allergens and additives, supporting overall wellness and heart health.")
                Text("You lean toward a plant‑forward, balanced lifestyle, choosing organic, seasonal, and low‑waste foods that feel good for both you and the Earth.")
                Text("With a taste for natural, less‑sweet flavors, you enjoy clean, wholesome meals that nourish you at every stage of life.")
            }
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale140)
            
        }
        .font(.system(size: 14))
        .foregroundStyle(Color(.label))
        .padding(16)
    }
}

private struct AISummarySectionRow: View {
    
    let section: AISummarySectionItem
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            VStack {
                SectionIconView(assetName: section.iconAssetName ?? "")
                
                Spacer()
            }
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "F3F3F3").opacity(0), Color(hex: "F3F3F3"), Color(hex: "F3F3F3").opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom)
                    )
                    .frame(width: 3)
                    .offset(y: 45)
                    .opacity(isLast ? 0 : 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(section.title)
                    .font(ManropeFont.extraBold.size(16))
                    .foregroundStyle(.grayScale150)

                BulletedPoints(points: section.bulletPoints)
            }
            .padding(.top, 10)
        }
    }
}

private struct SectionIconView: View {
    let assetName: String

    var body: some View {
        Circle()
            .foregroundStyle(
                LinearGradient(colors: [Color(hex: "FFF4E3"), Color(hex: "FFE9BE")], startPoint: .top, endPoint: .bottom)
            )
            .frame(width: 54, height: 54)
            .overlay(
                Image(assetName)
                    .resizable()
                    .frame(width: 28, height: 28)
            )
    }
}

private struct BulletedPoints: View {
    let points: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(points, id: \.self) { point in
                bulletRow(text: point)
            }
        }
    }

    @ViewBuilder
    private func bulletRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.top, -2)

            Text(text)
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GradientButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.75, blue: 0.10),
                                    Color(red: 0.22, green: 0.56, blue: 0.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                )
        }
    }
}
