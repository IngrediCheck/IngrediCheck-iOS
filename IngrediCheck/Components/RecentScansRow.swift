//
//  RecentScansRow.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct RecentScansRow: View {
    
    @State var feedback: Bool?
    
    init(feedback: Bool? = nil) {
        _feedback = State(initialValue: feedback)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            HStack{
                         Image("imagenotfound1")
                             .resizable()
                             .scaledToFill()
                             .frame(width: 20, height:20)
                            
                         }.frame(width: 42, height: 42)
                         .background(Color.grayScale50)
                         .cornerRadius(8)
            VStack(alignment: .leading, spacing: 4) {
                Text("Kellogg's Corn Flakes")
                    .font(ManropeFont.bold.size(12))
                    .foregroundStyle(.teritairy1000)
                
                Text("30 minutes ago")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(feedback == nil ? Color(hex: "#FCDE00") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
                    .frame(width: 10, height: 10)
                
                Text(feedback == nil ? "Uncertain" : feedback == true ? "Matched" : "Unmatched")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(feedback == nil ? Color(hex: "#FAB222") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(feedback == nil ? Color(hex: "#FFF9CE") : feedback == true ? .primary200 : Color(hex: "#FFE3E2"), in: RoundedRectangle(cornerRadius: 50))
        }
    }
}
struct HomeRecentScanRow: View {
    let item: DTO.HistoryItem
    
    @State private var image: UIImage? = nil
    @State private var isFavorited: Bool
    @State private var isTogglingFavorite: Bool = false
    @Environment(WebService.self) var webService

    init(item: DTO.HistoryItem) {
        self.item = item
        _isFavorited = State(initialValue: item.favorited)
    }
    
    private var feedback: Bool? {
        switch item.calculateMatch() {
        case .match:
            return true
        case .needsReview:
            return nil
        case .notMatch:
            return false
        }
    }
    
    private var titleText: String {
        let brand = item.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let brand, !brand.isEmpty, let name, !name.isEmpty {
            return "\(brand) \(name)"
        }
        return name ?? brand ?? "not available"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 55, height: 55)
                    .cornerRadius(8)
                    .clipped()
            } else {
                HStack{
                    Image("imagenotfound1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height:20)
                    
                }.frame(width: 55, height: 55)
                    .background(Color.grayScale50)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(titleText)
                    .font(ManropeFont.semiBold.size(14))
                    .foregroundStyle(.teritairy1000)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                  Circle()
                        .fill(feedback == nil ? Color(hex: "#FCDE00") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
                        .frame(width: 10, height: 10)
                    
                    Text(feedback == nil ? "Uncertain" : feedback == true ? "Matched" : "Unmatched")
                        .font(ManropeFont.medium.size(12))
                        .foregroundStyle(feedback == nil ? Color(hex: "#FF594E") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(feedback == nil ? Color(hex: "#FFF9CE") : feedback == true ? .primary200 : Color(hex: "#FFE3E2"), in: RoundedRectangle(cornerRadius: 25))
                
                //                Text(item.relativeTimeDescription())
                //                    .font(ManropeFont.regular.size(12))
                //                    .foregroundStyle(.grayScale100)
            }
        }
            
            Spacer()
            VStack(alignment: .trailing, spacing: 12) {
                Button {
                    guard !isTogglingFavorite else { return }
                    let previous = isFavorited
                    isFavorited.toggle()
                    isTogglingFavorite = true

                    print("[HomeRecentScanRow] favorite tap: scanId=\(item.client_activity_id), previous=\(previous), optimistic=\(isFavorited)")

                    Task {
                        do {
                            let updated = try await webService.setHistoryFavorite(
                                clientActivityId: item.client_activity_id,
                                favorited: isFavorited
                            )
                            await MainActor.run {
                                print("[HomeRecentScanRow] favorite success: scanId=\(item.client_activity_id), updated=\(updated)")
                                isFavorited = updated
                                isTogglingFavorite = false
                            }
                        } catch {
                            await MainActor.run {
                                print("[HomeRecentScanRow] favorite error: scanId=\(item.client_activity_id), error=\(error.localizedDescription)")
                                isFavorited = previous
                                isTogglingFavorite = false
                            }
                        }
                    }
                } label: {
                    Image("favoriate")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 18, height: 17)
                        .foregroundStyle(isFavorited ? Color(hex: "#FF1100") : .grayScale70)
                }
                .buttonStyle(.plain)
                .disabled(isTogglingFavorite)
                
                Text(item.relativeTimeDescription())
                .font(ManropeFont.regular.size(12))
                .foregroundStyle(.grayScale100)
                
        }
        .task {
            if let firstImage = item.images.first,
               let loaded = try? await webService.fetchImage(imageLocation: firstImage, imageSize: .small) {
                await MainActor.run {
                    image = loaded
                }
            }
        }
    }
}

#Preview {
    RecentScansRow()
        .padding(.horizontal, 20)
}
