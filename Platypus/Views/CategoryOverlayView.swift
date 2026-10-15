//
//  CategoriesOverlayView.swift
//  Platypus
//
//  Created by Yann Bernard on 15.09.26.
//

import SwiftUI

struct CategoryOverlayView: View {
    let uniqueLocationTags: UniqueLocationTags
    let imageDetections: ImageDetections

    var body: some View {
        VStack {
            HorizontalItems(collection: uniqueLocationTags)
            HorizontalItems(collection: imageDetections.summaries)
        }
    }
}

struct HorizontalItems<T: RandomAccessCollection>: View
where T.Element: Hashable & DisplayableProto {
    let collection: T

    private var items: [T.Element] {
        Array(collection)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92).combined(
                                with: .opacity
                            ),
                            removal: .scale(scale: 0.98).combined(
                                with: .opacity
                            )
                        )
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            itemLabel(item)
                                .transition(
                                    .asymmetric(
                                        insertion: .scale(scale: 0.8).combined(
                                            with: .opacity
                                        ),
                                        removal: .scale(scale: 0.8).combined(
                                            with: .opacity
                                        )
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(
                            with: .move(edge: .trailing)
                        ),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    )
                )
            }
        }
        .animation(
            .spring(response: 0.38, dampingFraction: 0.78),
            value: items
        )
    }

    private var emptyState: some View {
        Label(AppLanguage.current.localized("Nothing detected"), systemImage: "magnifyingglass")
            .font(.headline)
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.background, in: Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
    }

    private func itemLabel(_ item: T.Element) -> some View {
        Label(
            item.displayTitle,
            systemImage: item.symbolName
        )
        .font(.headline)
        .foregroundStyle(AppTheme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.background, in: Capsule())
    }
}
