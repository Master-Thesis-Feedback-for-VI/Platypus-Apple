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

    @StateObject private var locationRecorder = LocationRecorder()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var imageRecognizerStore = ImageRecognizerStore()

    @State private var selection: Tab = .home

    enum Tab { case home, live, camera, replay }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(Tab.home)

            LiveviewModeView()
                .environmentObject(locationRecorder)
                .environmentObject(cameraManager)
                .environmentObject(imageRecognizerStore)
                .tabItem {
                    Image(systemName: "camera")
                    Text("Live")
                }
                .tag(Tab.live)

            CameraView()
                .environmentObject(locationRecorder)
                .environmentObject(cameraManager)
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Record")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tag(Tab.camera)
            
            ReplayView()
                .tabItem {
                    Image(systemName: "play.square.fill")
                    Text("Replay")
                }.tag(Tab.replay)
        }
        .task {
            await imageRecognizerStore.load()
        }
        .onChange(of: selection) { _, newValue in
            Task {
                switch newValue {
                case .live, .camera:
                    await cameraManager.startSession()
                case .home, .replay:
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
