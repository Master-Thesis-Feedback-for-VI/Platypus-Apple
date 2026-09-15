//
//  CategoriesOverlayView.swift
//  Platypus
//
//  Created by Yann Bernard on 15.09.26.
//

import SwiftUI

struct CategoryOverlayView: View {
    let categories: [ContextCategory]

    var body: some View {
        if categories.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Label(
                            category.displayName,
                            systemImage: category.symbolName
                        )
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
