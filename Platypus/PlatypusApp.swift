//
//  PlatypusApp.swift
//  Platypus
//
//  Created by Yann Bernard on 07.08.26.
//

import SwiftData
import SwiftUI

let DOMAIN = "com.github.yannbernard.Platypus"

@main
struct PlatypusApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            //            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @StateObject private var mqttClient = PlatyMQTT(
        userName: infoValue("MQTT_USER"),
        passwd: infoValue("PASSWORD")
    )
    @StateObject private var locationRecorder = LocationRecorder()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var imageRecognizerStore = ImageRecognizerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(locationRecorder)
        .environmentObject(cameraManager)
        .environmentObject(imageRecognizerStore)
        .environmentObject(mqttClient)
    }
}
