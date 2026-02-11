//
//  ScannerResultCard.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 06/11/25.
//

import SwiftUI

enum ScannerResultOptions: String, CaseIterable, Identifiable {
    case loading
    case fetchingDetails
    case analysing
    case matched
    case unmatched
    case uncertain
    case retry
    case productNotFound
    
    var id: String { self.rawValue }
    
    var verdict: String? {
        switch self {
        case .loading, .productNotFound: return nil
        case .fetchingDetails: return "Fetching details..."
        case .analysing: return "Analysing..."
        case .matched: return "Matched"
        case .unmatched: return "Unmatched"
        case .uncertain: return "Uncertain"
        case .retry: return "Retry"
        }
    }
    
    var verdictMessage: String? {
        switch self {
        case .loading, .productNotFound, .fetchingDetails, .analysing: return nil
        case .matched: return "No major allergens detected"
        case .unmatched: return "Includes restricted items"
        case .uncertain: return "Needs a quick review"
        case .retry: return "Analysis failed !"
        }
    }
}

struct ScannerResultCard: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    ScannerResultCard()
}
