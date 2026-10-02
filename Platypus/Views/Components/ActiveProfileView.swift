//
//  ActiveProfileView.swift
//  Platypus
//
//  Created by Yann Bernard on 02.10.26.
//

import SwiftData
import SwiftUI

struct ActiveProfileView: View {
    @Query(
        filter: #Predicate<ProfileSettings> { $0.deletedAt == nil },
        sort: \ProfileSettings.created,
        animation: .default
    )
    private var profiles: [ProfileSettings]
    private var currentProfile: ProfileSettings {
        let activeProfiles = profiles.filter({ $0.isActive })
        precondition(activeProfiles.count == 1)
        return activeProfiles.first!
    }

    var body: some View {
        VStack {
            Text("Profile: \(currentProfile.name)")
        }
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
    }
}
