//
//  ProfileEditView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftData
import SwiftUI

struct ProfileEditView: View {
    private var language: AppLanguage { .current }
    let allOtherProfileNames: [String]

    @Bindable var profile: ProfileSettings

    @State private var draftName = ""
    @State private var rejectedName = ""
    @State private var showAlert = false

    var body: some View {
        ProfileEditSingularView(profile: profile)
            .onAppear {
                draftName = profile.name
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TextField(language.localized("Profile name"), text: $draftName)
                        .accessibilityLabel(
                            Text(verbatim: language.localized("Profile name"))
                        )
                        .accessibilityHint(
                            Text(verbatim: language.localized(
                                "Edit the profile name, then tap Done to save it."
                            ))
                        )
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
                        .foregroundStyle(AppTheme.text)
                        .background(AppTheme.background, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.text, lineWidth: 2))
                        .frame(maxWidth: 220)
                        .submitLabel(.done)
                }
            }
            .alert(
                rejectedName.isEmpty
                    ? language.localized("Profile name can't be empty")
                    : language.format("%@ already exists", rejectedName),
                isPresented: $showAlert,
            ) {
                Button(language.localized("OK"), role: .cancel) {}
            } message: {
                Text(verbatim:
                    language.localized(rejectedName.isEmpty
                        ? "Enter a name for this profile."
                        : "Choose a different name for this profile.")
                )
            }
    }
}
