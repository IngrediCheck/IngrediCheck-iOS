//
//  FilterSegmentedControl.swift
//  IngrediCheck
//
//  Segmented control for filtering recent scans between All and Favorites
//

import SwiftUI

enum RecentScansFilter {
    case all
    case favorites
}

struct FilterSegmentedControl: View {
    @Binding var selection: RecentScansFilter

    var body: some View {
        HStack(spacing: 0) {
            // All button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = .all
                }
            } label: {
                Microcopy.text(Microcopy.Key.Lists.RecentScansFilter.all)
                    .font(NunitoFont.semiBold.size(12))
                    .foregroundStyle(selection == .all ? .grayScale140 : .grayScale100)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(selection == .all ? Color.white : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            // Favorites button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = .favorites
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selection == .favorites ? .red : .grayScale100)

                    Microcopy.text(Microcopy.Key.Lists.RecentScansFilter.favoritesShort)
                        .font(NunitoFont.semiBold.size(12))
                        .foregroundStyle(selection == .favorites ? .grayScale140 : .grayScale100)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(selection == .favorites ? Color.white : Color.clear)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .frame(width: 105, height: 31)
        .background(
            Capsule()
                .stroke(Color.white)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        FilterSegmentedControl(selection: .constant(.all))
        FilterSegmentedControl(selection: .constant(.favorites))
    }
    .padding()
    .background(Color.pageBackground)
}
