//
//  ActiveProfileView.swift
//  Platypus
//
//  Created by Yann Bernard on 02.10.26.
//

import SwiftUI

struct ActiveProfileView: View {
    @Environment(ProfileManager.self) private var profileManager

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                activeProfileButton(name: "arrowshape.left") {
                    try? profileManager.prev()
                }

                Text(
                    profileManager.currentProfile.name
                )
                .contentTransition(.numericText())
                .animation(.default, value: profileManager.currentProfile.name)
                .font(.title2)
                .frame(width: 170)
                .padding(.vertical, 8)
                .glassEffect()

                activeProfileButton(name: "arrowshape.right") {
                    try? profileManager.next()
                }
            }
        }
        .padding()
    }

    private func activeProfileButton(
        name: String,
        perform: @escaping () -> Void
    ) -> some View {
        Button {
            perform()
        } label: {
            Image(systemName: name)
        }
        .font(.title2)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect()
    }
}
