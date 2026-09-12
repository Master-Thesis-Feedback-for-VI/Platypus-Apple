//
//  ContentView.swift
//  Platypus
//
//  Created by Yann Bernard on 07.08.26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var locationViewModel = LocationRecorder()
    @StateObject private var cameraManager = CameraManager()

    @State private var selection: Tab = .home

    enum Tab { case home, live, camera }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(Tab.home)

            LiveviewModeView()
                .environmentObject(locationViewModel)
                .environmentObject(cameraManager)
                .tabItem {
                    Image(systemName: "camera")
                    Text("Live")
                }
                .tag(Tab.live)

            CameraView()
                .environmentObject(locationViewModel)
                .environmentObject(cameraManager)
                .tabItem {
                    Image(systemName: "tv")
                    Text("Record Simulation")
                }
                .tag(Tab.camera)
        }
        .onChange(of: selection) { _, newValue in
            Task {
                switch newValue {
                case .live, .camera:
                    await cameraManager.startSession()
                case .home:
                    if cameraManager.isRecording {
                        await cameraManager.stopRecording()
                    }
                    await cameraManager.stopSession()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
