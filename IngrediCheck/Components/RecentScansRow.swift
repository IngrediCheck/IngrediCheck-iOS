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
    @Environment(AppState.self) var appState

    init(item: DTO.HistoryItem) {
        self.item = item
        _isFavorited = State(initialValue: item.favorited)
    }

    private var favoritedFromAppState: Bool {
        // Note: historyItems API has been replaced with scans API
        // For backwards compatibility, use item.favorited directly
        item.favorited
    }
    
    private var feedback: Bool? {
        switch item.calculateMatch() {
        case .match:
            return true
        case .needsReview:
            return nil
        case .notMatch:
            return false
        case .unknown:
            return nil  // Treat unknown as Uncertain (nil)
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
                    let previous = favoritedFromAppState
                    let next = !previous

                    // Optimistic UI + shared state update
                    isFavorited = next
                    appState.setHistoryItemFavorited(clientActivityId: item.client_activity_id, favorited: next)
                    isTogglingFavorite = true

                    print("[HomeRecentScanRow] favorite tap: scanId=\(item.client_activity_id), previous=\(previous), optimistic=\(isFavorited)")

                    Task {
                        do {
                            let updated = try await webService.setHistoryFavorite(
                                clientActivityId: item.client_activity_id,
                                favorited: next
                            )
                            await MainActor.run {
                                print("[HomeRecentScanRow] favorite success: scanId=\(item.client_activity_id), updated=\(updated)")
                                isFavorited = updated
                                appState.setHistoryItemFavorited(clientActivityId: item.client_activity_id, favorited: updated)
                                isTogglingFavorite = false
                            }

                            if let listItems = try? await webService.getFavorites() {
                                await MainActor.run {
                                    appState.listsTabState.listItems = listItems
                                }
                            }
                        } catch {
                            await MainActor.run {
                                print("[HomeRecentScanRow] favorite error: scanId=\(item.client_activity_id), error=\(error.localizedDescription)")
                                isFavorited = previous
                                appState.setHistoryItemFavorited(clientActivityId: item.client_activity_id, favorited: previous)
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
            if let firstImage = item.images.first {
                do {
                    print("[HomeRecentScanRow] Fetching image for history item: \(item.client_activity_id)")
                    let loaded = try await webService.fetchImage(imageLocation: firstImage, imageSize: .small)
                    await MainActor.run {
                        image = loaded
                    }
                } catch {
                    print("[HomeRecentScanRow] ❌ Failed to fetch image: \(error)")
                }
            } else {
                print("[HomeRecentScanRow] ⚠️ No images found for history item")
            }
        }
    }
}

struct ScanRow: View {
    let scan: DTO.Scan
    
    @State private var image: UIImage? = nil
    @State private var isFavorited: Bool
    @State private var isTogglingFavorite: Bool = false
    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(ScanHistoryStore.self) var scanHistoryStore
    
    init(scan: DTO.Scan) {
        self.scan = scan
        _isFavorited = State(initialValue: scan.is_favorited ?? false)
    }
    
    private var feedback: Bool? {
        switch scan.toProductRecommendation() {
        case .match:
            return true
        case .needsReview:
            return nil
        case .notMatch:
            return false
        case .unknown:
            return nil  // Treat unknown as Uncertain (nil)
        }
    }
    
    private var titleText: String {
        let brand = scan.product_info.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = scan.product_info.name?.trimmingCharacters(in: .whitespacesAndNewlines)
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
                }
                .frame(width: 55, height: 55)
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
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 12) {
                Button {
                    guard !isTogglingFavorite else { return }
                    let previous = isFavorited
                    let next = !previous
                    
                    // Optimistic UI update
                    isFavorited = next
                    isTogglingFavorite = true
                    
                    // Update app state
                    appState.setHistoryItemFavorited(clientActivityId: scan.id, favorited: next)
                    
                    print("[ScanRow] favorite tap: scanId=\(scan.id), previous=\(previous), optimistic=\(isFavorited)")
                    
                    Task {
                        do {
                            // Use new toggleFavorite API
                            let updated = try await webService.toggleFavorite(scanId: scan.id)
                            
                            await MainActor.run {
                                print("[ScanRow] favorite success: scanId=\(scan.id), updated=\(updated)")
                                isFavorited = updated
                                appState.setHistoryItemFavorited(clientActivityId: scan.id, favorited: updated)
                                isTogglingFavorite = false
                                
                                // Update scan in store
                                let newScan = DTO.Scan(
                                    id: scan.id,
                                    scan_type: scan.scan_type,
                                    barcode: scan.barcode,
                                    state: scan.state,
                                    product_info: scan.product_info,
                                    product_info_source: scan.product_info_source,
                                    product_info_vote: scan.product_info_vote,
                                    analysis_result: scan.analysis_result,
                                    images: scan.images,
                                    latest_guidance: scan.latest_guidance,
                                    created_at: scan.created_at,
                                    last_activity_at: scan.last_activity_at,
                                    is_favorited: updated,
                                    analysis_id: scan.analysis_id
                                )
                                scanHistoryStore.upsertScan(newScan)
                                
                                // Sync to AppState
                                if var scans = appState.listsTabState.scans {
                                    if let idx = scans.firstIndex(where: { $0.id == scan.id }) {
                                        scans[idx] = newScan
                                        appState.listsTabState.scans = scans
                                    }
                                }
                            }
                            
                            // Refresh favorites list
                            if let listItems = try? await webService.getFavorites() {
                                await MainActor.run {
                                    appState.listsTabState.listItems = listItems
                                }
                            }
                        } catch {
                            await MainActor.run {
                                print("[ScanRow] favorite error: scanId=\(scan.id), error=\(error.localizedDescription)")
                                isFavorited = previous
                                appState.setHistoryItemFavorited(clientActivityId: scan.id, favorited: previous)
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
                
                Text(scan.relativeTimeDescription())
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
            }
        }
        .task {
            // Get first image from scan using toProduct() logic which handles both inventory and user images
            let product = scan.toProduct()
            if let firstImage = product.images.first,
               let loaded = try? await webService.fetchImage(imageLocation: firstImage, imageSize: .small) {
                await MainActor.run {
                    image = loaded
                }
            }
        }
        .onChange(of: scan.is_favorited) { _, newValue in
            if let newValue = newValue, !isTogglingFavorite {
                isFavorited = newValue
            }
        }
    }
}

#Preview {
    RecentScansRow()
        .padding(.horizontal, 20)
}
