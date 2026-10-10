//
//  ProfileManager.swift
//  Platypus
//
//  Created by Yann Bernard on 06.10.26.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ProfileManager {
    struct SettingsSnapshot: Equatable {
        let profileID: PersistentIdentifier
        let settings: ProfileSingularSettings
    }

    private let ctx: ModelContext
    private(set) var profiles: [ProfileSettings] = []
    private(set) var trashed: [ProfileSettings] = []

    init(context: ModelContext) {
        self.ctx = context
        reload()
    }
}

extension ProfileManager {
    func reload() {
        let descriptor = FetchDescriptor<ProfileSettings>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.created)]
        )
        profiles = (try? ctx.fetch(descriptor)) ?? []

        let trashDescriptor = FetchDescriptor<ProfileSettings>(
            predicate: #Predicate { $0.deletedAt != nil },
            sortBy: [SortDescriptor(\.deletedAt)]
        )
        trashed = (try? ctx.fetch(trashDescriptor)) ?? []
        ensureAtLeastOneProfile()
    }

    var currentProfile: ProfileSettings {
        profiles.first(where: \.isActive)!
    }

    func settings(for location: PlatyLocationTag) -> SettingsSnapshot? {
        let profile = currentProfile
        let settings =
            profile.isLocationEnabled(location)
            ? profile.settings[location] ?? profile.defaultSettings
            : profile.defaultSettings
        return SettingsSnapshot(
            profileID: profile.persistentModelID,
            settings: settings
        )
    }

    var currentProfileIndex: Int {
        profiles.firstIndex(where: \.isActive)!
    }

    func activate(_ profile: ProfileSettings) throws {
        guard let target = profiles.firstIndex(where: { $0 === profile }),
            target != currentProfileIndex
        else { return }
        try swapActive(toActivate: target)
    }

    func prev(_ earconPlayer: EarconPlayer) throws {
        reload()
        if profiles.count == 1 { return }

        let target =
            (currentProfileIndex - 1 + profiles.count)
            % profiles.count
        try swapActive(toActivate: target)
        
        Task {
            await earconPlayer.play(PlatyMQTT.RecMessageVariants.prev, volume: 0.5, from: .front)
        }
    }

    func next(_ earconPlayer: EarconPlayer) throws {
        reload()
        if profiles.count == 1 { return }

        let target = (currentProfileIndex + 1) % profiles.count
        try swapActive(toActivate: target)
        
        Task {
            await earconPlayer.play(PlatyMQTT.RecMessageVariants.next, volume: 0.5, from: .front)
        }
    }

    func addProfile() throws {
        ctx.insert(ProfileSettings(name: uniqueName(from: "Profile")))
        try ctx.save()
        reload()
    }

    func deleteProfiles(at offsets: IndexSet) throws {
        guard profiles.count - offsets.count >= 1 else { return }

        let toDelete = offsets.map { profiles[$0] }
        let wasActiveDeleted = toDelete.contains { $0.isActive }
        let remaining = profiles.filter { p in !toDelete.contains { $0 === p } }

        let now = Date()
        for (i, p) in toDelete.enumerated() {
            p.isActive = false
            p.deletedAt = now.addingTimeInterval(Double(i) * 0.001)
        }
        if wasActiveDeleted { remaining.first?.isActive = true }

        try ctx.save()
        reload()
    }

    func purgeTrash() throws {
        for p in trashed where p.deletedAt != nil { ctx.delete(p) }
        try ctx.save()
        trashed.removeAll()
    }

    func undoDelete() {
        guard let profile = trashed.last else { return }
        profile.name = uniqueName(from: profile.name)
        profile.isActive = false
        profile.deletedAt = nil
        try? ctx.save()
        reload()
    }

    func uniqueName(from base: String) -> String {
        let names = Set(profiles.map(\.name))
        guard names.contains(base) else { return base }
        var i = 1
        while names.contains("\(base) - \(i)") { i += 1 }
        return "\(base) - \(i)"
    }

    private func swapActive(toActivate: Int) throws {
        let toDeactivate = currentProfileIndex

        profiles[toDeactivate].isActive = false
        profiles[toActivate].isActive = true

        do {
            try ctx.save()
        } catch {
            profiles[toActivate].isActive = false
            profiles[toDeactivate].isActive = true
            throw error
        }
    }

    private func ensureAtLeastOneProfile() {
        if profiles.isEmpty {
            let profile = ProfileSettings(name: uniqueName(from: "Profile"))
            profile.isActive = true
            ctx.insert(profile)
            try? ctx.save()
            profiles = [profile]
            return
        }
        let active = profiles.filter(\.isActive)
        switch active.count {
        case 1: return
        case 0: profiles.first?.isActive = true
        default: for p in profiles { p.isActive = (p === active.first!) }
        }
        try? ctx.save()
    }
}
