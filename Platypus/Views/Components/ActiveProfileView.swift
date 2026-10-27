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
    @AccessibilityFocusState(for: .voiceOver) private var focusedArrow: String?
    @State private var activatedArrow: String?

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                activeProfileButton(
                    name: "arrowshape.left",
                    accessibilityLabel: "Previous profile"
                ) {
                    try? profileManager.prev()
                }

                let profileText = Text(verbatim:
                    profileManager.currentProfile.name
                )
                .contentTransition(.numericText())
                .animation(.default, value: profileManager.currentProfile.name)
                .font(.title2)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
                .foregroundStyle(AppTheme.text)
                .background(AppTheme.background, in: Capsule())
                .accessibilityLabel(Text(verbatim: AppLanguage.current.format(
                    "Active profile: %@", profileManager.currentProfile.name
                )))
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
                    try? profileManager.next()
                }
            }
        }
        .padding()
        .onChange(of: focusedArrow) { _, newFocus in
            if activatedArrow != newFocus {
                activatedArrow = nil
            }
        }
    }

    private func announceActiveProfile() {
        let announcement = AppLanguage.current.format(
            "Active profile: %@", profileManager.currentProfile.name
        )
        let spokenAnnouncement = NSAttributedString(
            string: announcement,
            attributes: [.accessibilitySpeechQueueAnnouncement: false]
        )
        UIAccessibility.post(notification: .announcement, argument: spokenAnnouncement)
    }

    private func switchToNextProfile() {
        guard profileManager.profiles.count > 1 else { return }

        do {
            try profileManager.next()
            announceActiveProfile()
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
            activatedArrow = name
        } label: {
            Image(systemName: name)
        }
        .accessibilityLabel(Text(verbatim: activatedArrow == name
            ? AppLanguage.current.format("Active profile: %@", profileManager.currentProfile.name)
            : AppLanguage.current.localized(accessibilityLabel)))
        .accessibilityFocused($focusedArrow, equals: name)
        .font(.title2)
        .buttonStyle(HighContrastButtonStyle())
    }
}
