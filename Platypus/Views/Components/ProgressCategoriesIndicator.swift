//
//  ProgressCategoriesIndicator.swift
//  Platypus
//
//  Created by Yann Bernard on 15.09.26.
//

import SwiftUI

struct ProgressCategoriesIndicator: View {
    let progress: ProgressStatus

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(progress.color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(
                        progress == .evaluating && isPulsing ? 1.4 : 1.0
                    )
                    .opacity(progress == .evaluating && isPulsing ? 0.5 : 1.0)
                    .animation(
                        progress == .evaluating
                            ? .easeInOut(duration: 0.6).repeatForever(
                                autoreverses: true
                            )
                            : .spring(response: 0.35, dampingFraction: 0.6),
                        value: isPulsing
                    )
                    .onAppear {
                        if progress == .evaluating { isPulsing = true }
                    }
                    .onChange(of: progress) { _, newValue in
                        isPulsing = (newValue == .evaluating)
                    }

                Text(LocalizedStringKey(progress.label))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .animation(.easeInOut(duration: 0.25), value: progress)
        }
    }
}

enum ProgressStatus {
    case switchedOff, hardware, evaluating, failure, success, downloading

    var color: Color {
        switch self {
        case .switchedOff: return .gray
        case .hardware: return .blue
        case .evaluating: return .yellow
        case .downloading: return .yellow
        case .failure: return .red
        case .success: return .green
        }
    }

    var label: String {
        switch self {
        case .switchedOff: return "Off"
        case .hardware: return "Hardware"
        case .evaluating: return "Evaluating"
        case .failure: return "Failed"
        case .success: return "Success"
        case .downloading: return "Downloading"
        }
    }
}
