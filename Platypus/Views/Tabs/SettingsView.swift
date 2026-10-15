//
//  SettingsView.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    private var language: AppLanguage { .current }
    @EnvironmentObject private var earconEngine: EarconPlayer

    @Environment(ProfileManager.self) private var profileManager
    @Environment(\.scenePhase) private var scenePhase

    private let logger = PlatyLogger(tag: "StringSettingsView")

    var body: some View {
        NavigationStack {
            profileList(profileManager)
                .navigationTitle(language.localized("Available Profiles"))
                .toolbar { toolbarContent }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { try? profileManager.purgeTrash() }
                }
        }
    }

    private var sweepButton: some View {
        Button {
            Task {
                for detectionType in PlatyDetectionType.allCases {
                    logger.log(
                        "Now playing: \(detectionType.rawValue)",
                        level: .warning
                    )
                    await earconEngine.playSweep(
                        detectionType,
                        interval: .seconds(1)
                    )
                }
            }
        } label: {
            Label(language.localized("Sweep"), systemImage: "speaker")
        }
    }

    @ViewBuilder
    private func profileList(_ manager: ProfileManager) -> some View {
        let profiles = manager.profiles
        let list = List {
            ForEach(profiles) { profile in
                HStack {
                    Toggle(
                        language.localized("Active"),
                        isOn: activeBinding(for: profile, in: manager)
                    )
                    .labelsHidden()
                    .accessibilityLabel(Text(verbatim: language.format("Profile %@", profile.name)))
                    .accessibilityValue(
                        Text(verbatim: language.localized(profile.isActive ? "Active" : "Inactive"))
                    )
                    .accessibilityHint(
                        Text(verbatim:
                            language.localized(
                                profile.isActive
                                    ? "Choose another profile to make it active."
                                    : "Makes this the active profile."
                            )
                        )
                    )
                    .disabled(profile.isActive || profiles.count <= 1)
                    NavigationLink(profile.name) {
                        ProfileEditView(
                            allOtherProfileNames: profiles.filter {
                                $0 !== profile
                            }.map(\.name),
                            profile: profile
                        )
                    }
                    .accessibilityLabel(Text(verbatim: language.format("Edit %@", profile.name)))
                    .accessibilityValue(
                        Text(verbatim:
                            language.localized(
                                profile.isActive
                                    ? "Active profile" : "Inactive profile"
                            )
                        )
                    )
                    .accessibilityHint(Text(verbatim: language.localized("Opens this profile's settings.")))
                }
                .deleteDisabled(profiles.count <= 1)
            }
            .onDelete { try? manager.deleteProfiles(at: $0) }

        }
        .contentMargins(.top, 22, for: .scrollContent)
        .animation(.default, value: profiles.map(\.isActive))

        if profiles.count > 1 {
            list.accessibilityAction(.magicTap, switchToNextProfile)
        } else {
            list
        }
    }

    private func switchToNextProfile() {
        guard profileManager.profiles.count > 1 else { return }
        do {
            try withAnimation { try profileManager.next(earconEngine) }
            UIAccessibility.post(
                notification: .announcement,
                argument:
                    language.format(
                        "Active profile: %@",
                        profileManager.currentProfile.name
                    )
            )
        } catch {
            logger.log("Could not switch profile: \(error)", level: .error)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: profileManager.undoDelete) {
                Label(language.localized("Undo"), systemImage: "arrow.uturn.backward")
            }
            .accessibilityLabel(Text(verbatim: language.localized("Undo profile deletion")))
            .accessibilityHint(Text(verbatim: language.localized("Restores the most recently deleted profile.")))
            .disabled(profileManager.trashed.isEmpty)

            Button(
                language.localized("Add"),
                systemImage: "plus",
                action: { try? profileManager.addProfile() }
            )
            .accessibilityLabel(Text(verbatim: language.localized("Add profile")))
            .accessibilityHint(Text(verbatim: language.localized("Creates a new profile.")))
        }
    }

    private func activeBinding(
        for profile: ProfileSettings,
        in manager: ProfileManager
    ) -> Binding<Bool> {
        Binding(
            get: { profile.isActive },
            set: { newValue in
                if newValue { withAnimation { try? manager.activate(profile) } }
            }
        )
    }

}
