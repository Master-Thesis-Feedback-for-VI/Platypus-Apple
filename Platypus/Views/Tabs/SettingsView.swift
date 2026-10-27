//
//  SettingsView.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import SwiftData
import SwiftUI
import Synchronization
import UIKit

let IMPORTED = Mutex(false)

struct SettingsView: View {
    private var language: AppLanguage { .current }

    @EnvironmentObject private var earconEngine: EarconPlayer
    @EnvironmentObject private var mqttClient: PlatyMQTT
    @Namespace private var namespace

    @Environment(ProfileManager.self) private var profileManager
    @Environment(\.scenePhase) private var scenePhase

    private let logger = PlatyLogger(tag: "StringSettingsView")

    var body: some View {
        NavigationStack {
            profileList(profileManager)
                .navigationTitle(language.localized("Available Profiles"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar { toolbarContent }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { try? profileManager.purgeTrash() }
                }
        }
        .onAppear {
            Task {
                try? await importProfiles()
            }

            let topic = AvailableTopics.profileSwap
            let cb: (PlatyMQTT.RecMessage) -> Void = { msg in
                logger.log("Received msg: \(msg)")
                ProfileManager.swapProfile(
                    msg: msg,
                    pm: profileManager
                )
            }

            mqttClient.addCallback(
                topic: topic,
                namespace: namespace,
                cb: cb
            )
        }.onDisappear {
            mqttClient.flushCallbacks(namespace: namespace)
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
                HStack(spacing: 24) {
                    Toggle(
                        language.localized("Active"),
                        isOn: activeBinding(for: profile, in: manager)
                    )
                    .labelsHidden()
                    .accessibilityLabel(
                        Text(
                            verbatim: language.format(
                                "Profile %@",
                                profile.name
                            )
                        )
                    )
                    .accessibilityValue(
                        Text(
                            verbatim: language.localized(
                                profile.isActive ? "Active" : "Inactive"
                            )
                        )
                    )
                    .accessibilityHint(
                        Text(
                            verbatim:
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
                    .accessibilityLabel(
                        Text(verbatim: language.format("Edit %@", profile.name))
                    )
                    .accessibilityValue(
                        Text(
                            verbatim:
                                language.localized(
                                    profile.isActive
                                        ? "Active profile" : "Inactive profile"
                                )
                        )
                    )
                    .accessibilityHint(
                        Text(
                            verbatim: language.localized(
                                "Opens this profile's settings."
                            )
                        )
                    )
                }
                .deleteDisabled(profiles.count <= 1)
            }
            .onDelete { try? manager.deleteProfiles(at: $0) }

        }
        .contentMargins(.top, 22, for: .scrollContent)
        .highContrastForm()
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
            try withAnimation { try profileManager.next() }
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
        ToolbarItem(placement: .principal) {
            Text(verbatim: language.localized("Available Profiles"))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: profileManager.undoDelete) {
                Label(
                    language.localized("Undo"),
                    systemImage: "arrow.uturn.backward"
                )
            }
            .accessibilityLabel(
                Text(verbatim: language.localized("Undo profile deletion"))
            )
            .accessibilityHint(
                Text(
                    verbatim: language.localized(
                        "Restores the most recently deleted profile."
                    )
                )
            )
            .buttonStyle(HighContrastButtonStyle(isToolbarButton: true))
            .disabled(profileManager.trashed.isEmpty)

            Button(
                language.localized("Add"),
                systemImage: "plus",
                action: { try? profileManager.addProfile() }
            )
            .accessibilityLabel(
                Text(verbatim: language.localized("Add profile"))
            )
            .accessibilityHint(
                Text(verbatim: language.localized("Creates a new profile."))
            )
            .buttonStyle(HighContrastButtonStyle(isToolbarButton: true))
        }
        .sharedBackgroundVisibility(.hidden)
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

    private func importProfiles() async throws {
        // UI tests start with a single profile, independent of bundled or local imports.
        guard !PlatypusApp.isUITesting else { return }

        let imported = IMPORTED.withLock { $0 }
        if imported { return }

        let fm = FileManager.default
        let importDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("import_dir", isDirectory: true)
        try fm.createDirectory(at: importDir, withIntermediateDirectories: true)

        var jsonFiles = try fm.contentsOfDirectory(
            at: importDir,
            includingPropertiesForKeys: nil
        ).filter {
            $0.pathExtension.lowercased() == "json"
        }
        let defaultJsonFiles =
            Bundle.main.urls(
                forResourcesWithExtension: "json",
                subdirectory: "DefaultProfiles"
            ) ?? []

        jsonFiles += defaultJsonFiles

        let decoder = JSONDecoder()
        for jsonFile in jsonFiles {
            do {
                let data = try Data(contentsOf: jsonFile)
                let profile = try decoder.decode(
                    ProfileSettings.self,
                    from: data
                )
                try profileManager.insertProfile(profile)
            }
        }

        IMPORTED.withLock { $0.toggle() }
    }
}
