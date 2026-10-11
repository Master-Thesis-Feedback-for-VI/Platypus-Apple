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
    @EnvironmentObject private var earconEngine: EarconPlayer

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                activeProfileButton(
                    name: "arrowshape.left",
                    accessibilityLabel: "Previous profile"
                ) {
                    try? profileManager.prev(earconEngine)
                }

                let profileText = Text(verbatim:
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

                activeProfileButton(
                    name: "arrowshape.right",
                    accessibilityLabel: "Next profile"
                ) {
                    try? profileManager.next(earconEngine)
                }
            }
        }
        .padding()
        .onChange(of: profileManager.currentProfile.name) { _, newName in
            AccessibilityNotification.Announcement(
                AppLanguage.current.format("Active profile: %@", newName)
            ).post()
        }
    }

    private func switchToNextProfile() {
        guard profileManager.profiles.count > 1 else { return }

        do {
            try profileManager.next(earconEngine)
            UIAccessibility.post(
                notification: .announcement,
                argument:
                    AppLanguage.current.format("Active profile: %@", profileManager.currentProfile.name)
            )
        } catch {
            logger.log("Could not switch profile: \(error)", level: .error)
        }
    }

    private func activeProfileButton(
        name: String,
        accessibilityLabel: String,
        perform: @escaping () -> Void
    ) -> some View {
        Button {
            perform()
        } label: {
            Image(systemName: name)
        }
        .accessibilityLabel(Text(verbatim: AppLanguage.current.localized(accessibilityLabel)))
        .font(.title2)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect()
    }
}
