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

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var imageRecognizerStore: ImageRecognizerStore

    @State private var selection: Tab = .settings
    @State private var profileManager: ProfileManager?

    enum Tab { case settings, live, camera, replay }

    var body: some View {
        if let profileManager {
            TabView(selection: $selection) {
                LiveviewModeView()
                    .tabItem {
                        Image(systemName: "camera")
                        Text("Live")
                    }
                    .tag(Tab.live)

                CameraView()
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

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                    .tag(Tab.settings)

            }
            .environment(profileManager)
            .task {
                await imageRecognizerStore.load()
            }
            .onChange(of: selection) { _, newValue in
                Task {
                    switch newValue {
                    case .live, .camera:
                        await cameraManager.startSession()
                    case .settings, .replay:
                        if cameraManager.isRecording {
                            await cameraManager.stopRecording()
                        }
                        await cameraManager.stopSession()
                    }
                }
            }
        } else {
            Color.clear.task {
                profileManager = ProfileManager(context: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
}
