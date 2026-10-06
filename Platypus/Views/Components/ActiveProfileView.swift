//
//  ActiveProfileView.swift
//  Platypus
//
//  Created by Yann Bernard on 02.10.26.
//

import SwiftData
import SwiftUI

struct ActiveProfileView: View {
    @State private var profileManager: ProfileManager?
    @Environment(\.modelContext) private var ctx

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                activeProfileButton(name: "arrowshape.left") {
                    try? profileManager?.prev()
                }

                Text(
                    "\(profileManager?.currentProfile.name ?? "Loading...")"
                )
                .contentTransition(.numericText())
                .animation(.default, value: profileManager?.currentProfile.name)
                .font(.title2)
                .frame(width: 170)
                .padding(.vertical, 8)
                .glassEffect()

                activeProfileButton(name: "arrowshape.right") {
                    try? profileManager?.next()
                }
            }
        }
        .padding()
        .onAppear {
            profileManager = ProfileManager(context: ctx)
        }
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
