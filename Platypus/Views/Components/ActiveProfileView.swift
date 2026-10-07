//
//  ActiveProfileView.swift
//  Platypus
//
//  Created by Yann Bernard on 02.10.26.
//

import SwiftUI

struct ActiveProfileView: View {
    let logger = PlatyLogger(tag: "ActiveProfileView")
    
    @Environment(ProfileManager.self) private var profileManager

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                activeProfileButton(name: "arrowshape.left") {
                    try? profileManager.prev()
                }

                let profileText = Text(
                    profileManager.currentProfile.name
                )
                .contentTransition(.numericText())
                .animation(.default, value: profileManager.currentProfile.name)
                .font(.title2)
                .frame(width: 170)
                .padding(.vertical, 8)
                .glassEffect()
                .accessibilityAction(.magicTap) {}

                let profiles = profileManager.profiles
                if profiles.count > 1 {
                    profileText.accessibilityAction(
                        .magicTap,
                        switchToNextProfile
                    )
                } else {
                    profileText
                }

                activeProfileButton(name: "arrowshape.right") {
                    try? profileManager.next()
                }
            }
        }
        .padding()
    }

    private func switchToNextProfile() {
        guard profileManager.profiles.count > 1 else { return }

        do {
            try profileManager.next()
            UIAccessibility.post(
                notification: .announcement,
                argument:
                    "Active profile: \(profileManager.currentProfile.name)"
            )
        } catch {
            logger.log("Could not switch profile: \(error)", level: .error)
        }
    }

    private func activeProfileButton(
        name: String,
        perform: @escaping () -> Void
    ) -> some View {
        Button {
            perform()
        } label: {
            Image(systemName: name)
        }
        .font(.title2)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect()
    }
}
