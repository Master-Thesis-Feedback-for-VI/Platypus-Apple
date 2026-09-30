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
                            ProfileEditView(profile: profile)
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
        if profiles.isEmpty { addProfile() }
    }
}

struct ProfileEditView: View {
    @Bindable var profile: ProfileSettings

    var body: some View {
        Form {
            TextField("Name", text: $profile.name)

            ForEach(ProfileDetectionTypes.allCases) { type in
                if let binding = binding(for: type) {
                    Section(type.rawValue) {
                        Picker("Sound", selection: binding.sound.soundVariant) {
                            ForEach(SoundVariants.allCases, id: \.self) {
                                Text($0.rawValue.uppercased()).tag($0)
                            }
                        }
                        Slider(value: binding.sound.volume, in: 0...1)
                        Toggle("Haptics", isOn: binding.haptic.switchedOn)
                        Slider(value: binding.haptic.intensity, in: 0...1)
                    }
                }
            }
        }
    }

    private func binding(for type: ProfileDetectionTypes) -> Binding<
        ProfileDetectionSettings
    >? {
        guard profile.detectionSettings[type] != nil else { return nil }
        return Binding(
            get: { profile.detectionSettings[type]! },
            set: { profile.detectionSettings[type] = $0 }
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ProfileSettings.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(ProfileSettings(name: "Default"))
    return ContentView().modelContainer(container)
}
