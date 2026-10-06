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
        HStack {
            Button {
                
            } label: {
                Label("Prev", systemImage: "arrowshape.left")
            }
            
            Text("Profile: \(profileManager?.currentProfile.name ?? "Loading...")")
        }
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear {
            profileManager = ProfileManager(context: ctx)
        }
    }
}
