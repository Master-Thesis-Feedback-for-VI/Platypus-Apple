//
//  ProfileEditView.swift
//  Platypus
//
//  Created by Yann Bernard on 30.09.26.
//

import SwiftUI

struct ProfileEditView: View {
    @State var profile: ProfileSettings

    var body: some View {
        ProfileEditSingularView(profile: profile)
    }
}
