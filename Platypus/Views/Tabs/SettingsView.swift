//
//  SettingsView.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var earconEngine: EarconPlayer
    
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        filter: #Predicate<ProfileSettings> { $0.deletedAt == nil },
        sort: \ProfileSettings.created,
        animation: .default
    )
    private var profiles: [ProfileSettings]

    @Query(
        filter: #Predicate<ProfileSettings> { $0.deletedAt != nil },
        sort: \ProfileSettings.deletedAt
    )
    private var trashed: [ProfileSettings]
    
    private let logger = PlatyLogger(tag: "StringSettingsView")

    var body: some View {
        NavigationStack {
            VStack {
                Button {
                    Task {
                        for detectionType in PlatyDetectionType.allCases {
                            logger.log("Now playing: \(detectionType.rawValue)", level: .warning)
                            await earconEngine.playSweep(detectionType, interval: .seconds(1))
                        }
                    }
                } label: {
                    Label("Sweep", systemImage: "speaker")
                }
                
                List {
                    ForEach(profiles) { profile in
                        HStack {
                            Toggle("Active", isOn: activeBinding(for: profile))
                                .labelsHidden()
                                .disabled(profiles.count <= 1)
                            NavigationLink(profile.name) {
                                ProfileEditView(
                                    allOtherProfileNames:
                                        profiles
                                        .filter { $0 !== profile }
                                        .map(\.name),
                                    profile: profile
                                )
                            }
                        }
                        .deleteDisabled(profiles.count <= 1)
                    }
                    .onDelete(perform: deleteProfiles)
                }
                .animation(.default, value: profiles.map(\.isActive))
                .navigationTitle("Available Profiles")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: undoDelete) {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(trashed.isEmpty)
                        
                        Button("Add", systemImage: "plus", action: addProfile)
                    }
                }
                .onAppear(perform: ensureAtLeastOneProfile)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { purgeTrash() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func uniqueName(from base: String) -> String {
        let names = Set(profiles.map(\.name))
        guard names.contains(base) else { return base }
        var i = 1
        while names.contains("\(base) - \(i)") { i += 1 }
        return "\(base) - \(i)"
    }

    private func purgeTrash() {
        trashed.forEach(ctx.delete)
    }

    // MARK: - Actions

    private func addProfile() {
        withAnimation {
            ctx.insert(
                ProfileSettings(
                    name: uniqueName(from: "Profile")
                )
            )
        }
    }

    private func undoDelete() {
        guard let profile = trashed.last else { return }
        withAnimation {
            profile.name = uniqueName(from: profile.name)
            profile.isActive = false
            profile.deletedAt = nil
        }
    }

    private func activeBinding(for profile: ProfileSettings) -> Binding<Bool> {
        Binding(
            get: { profile.isActive },
            set: { newValue in
                withAnimation {
                    if newValue || profiles.count == 1 {
                        for p in profiles { p.isActive = (p === profile) }
                    } else {
                        profile.isActive = false
                    }
                }
            }
        )
    }

    private func deleteProfiles(at offsets: IndexSet) {
        guard profiles.count - offsets.count >= 1 else { return }

        let toDelete = offsets.map { profiles[$0] }
        let wasActiveDeleted = toDelete.contains { $0.isActive }
        let remaining = profiles.filter { p in !toDelete.contains { $0 === p } }

        withAnimation(.snappy) {
            let now = Date()
            for (i, p) in toDelete.enumerated() {
                p.isActive = false
                p.deletedAt = now.addingTimeInterval(Double(i) * 0.001)  // keeps undo order stable
            }
            if wasActiveDeleted { remaining.first?.isActive = true }
        }
    }

    private func ensureAtLeastOneProfile() {
        purgeTrash()
        if profiles.isEmpty {
            let profile = ProfileSettings(
                name: uniqueName(from: "Profile")
            )
            profile.isActive = true
            withAnimation {
                ctx.insert(profile)
            }
            return
        }
        let active = profiles.filter(\.isActive)
        switch active.count {
        case 1: break
        case 0: profiles.first?.isActive = true
        default: for p in profiles { p.isActive = (p === active.first!) }
        }
    }
}
