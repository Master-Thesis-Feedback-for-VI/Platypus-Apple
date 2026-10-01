//
//  SettingsView.swift
//  Platypus
//
//  Created by Yann Bernard on 29.09.26.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \ProfileSettings.name) private var profiles: [ProfileSettings]

    var body: some View {
        NavigationStack {
            List {
                ForEach(profiles) { profile in
                    HStack {
                        Toggle("Active", isOn: activeBinding(for: profile))
                            .labelsHidden()
                            .disabled(profiles.count <= 1)
                        NavigationLink(profile.name) {
                            ProfileEditView(
                                allOtherProfileNames: profiles.filter {
                                    $0 !== profile
                                }.map { $0.name },
                                profile: profile
                            )
                        }
                    }
                    .deleteDisabled(profiles.count <= 1)
                }
                .onDelete(perform: deleteProfiles)
            }
            .navigationTitle("Available Profiles")
            .toolbar {
                Button("Add", systemImage: "plus", action: addProfile)
            }
            .onAppear(perform: ensureAtLeastOneProfile)
        }.onAppear {
            ensureAtLeastOneProfile()
        }
    }

    private func addProfile() {
        let name = "Profile \(profiles.count + 1)"
        ctx.insert(ProfileSettings(name: name))
    }

    private func activeBinding(for profile: ProfileSettings) -> Binding<Bool> {
        return Binding(
            get: { profile.isActive },
            set: { newValue in
                if newValue || profiles.count == 1 {
                    for p in profiles {
                        p.isActive = (p === profile)
                    }
                } else {
                    profile.isActive = false
                }
            }
        )
    }

    private func deleteProfiles(at offsets: IndexSet) {
        guard profiles.count - offsets.count >= 1 else { return }

        let wasActiveDeleted = offsets.contains { profiles[$0].isActive }
        let toDelete = offsets.map { profiles[$0] }
        toDelete.forEach(ctx.delete)

        // Keep one profile active if the active one was removed
        if wasActiveDeleted,
            let fallback = profiles.first(where: { p in
                !toDelete.contains { $0 === p }
            })
        {
            fallback.isActive = true
        }
    }

    private func ensureAtLeastOneProfile() {
        if profiles.isEmpty {
            let profile = ProfileSettings(name: "Profile 1")
            profile.isActive = true
            ctx.insert(profile)
            return
        }

        let active = profiles.filter { $0.isActive }

        switch active.count {
        case 1:
            break
        case 0:
            profiles.first?.isActive = true
        default:
            for p in profiles {
                p.isActive = (p === active.first!)
            }
        }
    }
}
