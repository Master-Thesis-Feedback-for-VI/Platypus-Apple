//
//  ProgressIndicatorView.swift
//  Platypus
//
//  Created by Yann Bernard on 24.09.26.
//

import SwiftUI

struct ProgressIndicatorView: View {
    @State var progress: ProgressStatus = .switchedOff
    @State var uniqueLocationTags: UniqueLocationTags
    @State var detectedObjects: ImageDetections

    var body: some View {
        VStack {
            ProgressCategoriesIndicator(progress: progress)
                .padding(.top, 15)

            Spacer()

            CategoryOverlayView(
                uniqueLocationTags: uniqueLocationTags,
                imageDetections: detectedObjects
            )
            .padding(.bottom, 24)
        }
    }
}
