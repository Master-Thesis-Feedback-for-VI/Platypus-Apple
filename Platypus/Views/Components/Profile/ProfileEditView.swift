//
//  ProfileEditView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftData
import SwiftUI

struct ProfileEditView: View {
    let allOtherProfileNames: [String]

    @Bindable var profile: ProfileSettings
    @State private var selectedTag: ProfileLocationTag = .allCases.first!

    @State private var draftName = ""
    @State private var rejectedName = ""
    @State private var showAlert = false

    var body: some View {
        VStack {
            if let binding = settingsBinding(for: selectedTag) {
                ProfileEditSingularView(profile: binding)
            }
        }
        .animation(.default, value: selectedTag)
        .onAppear {
            draftName = profile.name
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Profile name", text: $draftName)
                    .onSubmit {
                        let trimmed = draftName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        let taken = allOtherProfileNames.contains { otherName in
                            trimmed == otherName
                        }

                        if !trimmed.isEmpty && !taken {
                            profile.name = trimmed
                        } else {
                            rejectedName = trimmed
                            showAlert = true
                            draftName = profile.name
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect()
                    .frame(maxWidth: 220)
                    .submitLabel(.done)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Picker("Location", selection: $selectedTag) {
                    ForEach(ProfileLocationTag.allCases) { tag in
                        Text(tag.rawValue.capitalized).tag(tag)
                    }
                }.pickerStyle(.menu).labelsHidden().fixedSize()
            }
        }
        .alert(
            rejectedName.isEmpty
                ? "Name can't be empty"
                : "\(rejectedName) already exists",
            isPresented: $showAlert,
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please select a unique name.")
        }
    }

    // MARK: - Actions

    private func settingsBinding(for tag: ProfileLocationTag) -> Binding<
        ProfileSingularSettings
    >? {
        guard let current = profile.settings[tag] else { return nil }
        return Binding(
            get: { profile.settings[tag] ?? current },
            set: { newVal in
                withAnimation { profile.settings[tag] = newVal }
            }
        )
    }
}
