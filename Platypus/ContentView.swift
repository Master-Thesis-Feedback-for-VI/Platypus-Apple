//
//  ContentView.swift
//  Platypus
//
//  Created by Yann Bernard on 07.08.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            
            CameraView()
                .tabItem {
                    Image(systemName: "camera")
                    Text("Camera")
                }
        }
    }
}

#Preview {
    ContentView()
}
