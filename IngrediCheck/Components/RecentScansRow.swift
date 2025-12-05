//
//  RecentScansRow.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/10/25.
//

import SwiftUI

struct RecentScansRow: View {
    
    @State var feedback: Bool? = nil
    
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
                    .foregroundStyle(feedback == nil ? Color(hex: "#FF594E") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
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
    @Environment(WebService.self) var webService
    
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
                    .frame(width: 42, height: 42)
                    .cornerRadius(8)
                    .clipped()
            } else {
                HStack{
                            Image("imagenotfound1")
                                 .resizable()
                                 .scaledToFill()
                                 .frame(width: 20, height:20)
                                 
                             }.frame(width: 42, height: 42)
                             .background(Color.grayScale50)
                             .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(ManropeFont.bold.size(12))
                    .foregroundStyle(.teritairy1000)
                    .lineLimit(1)
                
                Text(item.relativeTimeDescription())
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
                    .foregroundStyle(feedback == nil ? Color(hex: "#FF594E") : feedback == true ? .primary600 : Color(hex: "#FF1100"))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(feedback == nil ? Color(hex: "#FFF9CE") : feedback == true ? .primary200 : Color(hex: "#FFE3E2"), in: RoundedRectangle(cornerRadius: 12))
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
