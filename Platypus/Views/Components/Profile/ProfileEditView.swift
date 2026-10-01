//
//  ProfileEditView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftUI

struct ProfileEditView: View {
    @State var profile: ProfileSettings
    @State private var selectedTag: ProfileLocationTag = .allCases.first!

    var body: some View {
        //        ForEach(ProfileLocationTag.allCases) { tag in
        //            Text("\(tag.rawValue.capitalized)")
        //        }
        VStack {
            ProfileEditSingularView(profile: profile)
        }.toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Picker("Location", selection: $selectedTag) {
                    ForEach(ProfileLocationTag.allCases) { tag in
                        Text(tag.rawValue.capitalized).tag(tag)
                    }
                }.pickerStyle(.menu).labelsHidden().fixedSize()
            }
        }
    }
}
