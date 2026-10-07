//
//  SettingsView.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    private let earconEngine = EarconPlayer(earcons: PlatyDetectionType.allCases)

    @Environment(ProfileManager.self) private var profileManager
    @Environment(\.scenePhase) private var scenePhase

    private let logger = PlatyLogger(tag: "StringSettingsView")

    var body: some View {
        NavigationStack {
            VStack {
                sweepButton

                profileList(profileManager)
            }
            .navigationTitle("Available Profiles")
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
            Label("Sweep", systemImage: "speaker")
        }
    }

    private func profileList(_ manager: ProfileManager) -> some View {
        let profiles = manager.profiles
        return List {
            ForEach(profiles) { profile in
                HStack {
                    Toggle(
                        "Active",
                        isOn: activeBinding(for: profile, in: manager)
                    )
                    .labelsHidden()
                    .disabled(profiles.count <= 1)
                    NavigationLink(profile.name) {
                        ProfileEditView(
                            allOtherProfileNames: profiles.filter {
                                $0 !== profile
                            }.map(\.name),
                            profile: profile
                        )
                    }
                }
                .deleteDisabled(profiles.count <= 1)
            }
            .onDelete { try? manager.deleteProfiles(at: $0) }
        }
        .animation(.default, value: profiles.map(\.isActive))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: profileManager.undoDelete) {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(profileManager.trashed.isEmpty)

            Button(
                "Add",
                systemImage: "plus",
                action: { try? profileManager.addProfile() }
            )
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
