//
//  HomeView.swift
//  Platypus
//
//  Created by Assistant on 08.11.26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "house.fill")
                    .font(.system(size: 48))
                Text("Home")
                    .font(.title2)
                    .bold()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
