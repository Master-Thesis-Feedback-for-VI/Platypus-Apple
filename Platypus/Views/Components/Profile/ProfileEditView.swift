//
//  ProfileEditView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftData
import SwiftUI

let ENABLE_EXPORT = true

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
                    TitleRenameFieldView(
                        allOtherProfileNames: allOtherProfileNames,
                        draftName: $draftName,
                        rejectedName: $rejectedName,
                        showAlert: $showAlert,
                        profile: profile
                    )
                }

                if ENABLE_EXPORT {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = [
                                .prettyPrinted, .sortedKeys,
                            ]

                            guard let data = try? encoder.encode(profile) else {
                                return
                            }
                            try? exportProfile(data, profile.name)
                        } label: {
                            Label("export", systemImage: "square.and.arrow.up")
                        }
                    }
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
                Text(
                    verbatim:
                        language.localized(
                            rejectedName.isEmpty
                                ? "Enter a name for this profile."
                                : "Choose a different name for this profile."
                        )
                )
            }
    }

    private func exportProfile(_ data: Data, _ profileName: String) throws {
        let fm = FileManager.default
        let userDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportDir = userDir.appendingPathComponent(
            "profile_export",
            isDirectory: true
        )

        try fm.createDirectory(
            at: exportDir,
            withIntermediateDirectories: true,
        )

        let filePath = exportDir
            .appendingPathComponent(profileName)
            .appendingPathExtension("json")

        try data.write(to: filePath, options: .atomic)
    }
}

struct TitleRenameFieldView: View {
    private var language: AppLanguage { .current }

    let allOtherProfileNames: [String]

    @Binding var draftName: String
    @Binding var rejectedName: String
    @Binding var showAlert: Bool

    @Bindable var profile: ProfileSettings

    var body: some View {
        TextField(language.localized("Profile name"), text: $draftName)
            .accessibilityLabel(
                Text(verbatim: language.localized("Profile name"))
            )
            .accessibilityHint(
                Text(
                    verbatim: language.localized(
                        "Edit the profile name, then tap Done to save it."
                    )
                )
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
