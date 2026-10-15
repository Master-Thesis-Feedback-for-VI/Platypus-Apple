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
    init() {
        AppTheme.configureAppearance()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ProfileSettings.self])
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
            print("ModelContainer failed, wiping store: \(error)")
            let storeURL = modelConfiguration.url
            let fm = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                let url =
                    suffix.isEmpty
                    ? storeURL
                    : URL(fileURLWithPath: storeURL.path + suffix)
                try? fm.removeItem(at: url)
            }
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError(
                    "Could not create ModelContainer after reset: \(error)"
                )
            }
        }
    }()

    @StateObject private var mqttClient = PlatyMQTT(
        userName: infoValue("MQTT_USER"),
        passwd: infoValue("PASSWORD")
    )
    @StateObject private var locationRecorder = LocationRecorder()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var imageRecognizerStore = ImageRecognizerStore()
    @StateObject private var earconEngine = EarconPlayer(
        earcons: PlatyDetectionType.allCases + PlatyMQTT.RecMessageVariants.allCases
    )

    private let logger = PlatyLogger(tag: "Root")

    @Environment(\.scenePhase) private var scenePhase
    @State private var didConnect = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .highContrastTheme()
                .environment(\.locale, AppLanguage.current.locale)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        guard !didConnect else { return }
                        didConnect = true
//                        let _ = enableTracing(rustLog: .debug)
                        Task {
                            logger.log("Connecting to mqtt server...")
                            do {
                                try await mqttClient
                                    .subscribeToTopics(to: .profileSwap)
                                logger.log("... Connected to mqtt server")
                                mqttClient.startLoop()
                            } catch {
                                didConnect = false
                                logger.log(
                                    "Failed to connect to mqtt server: \(error)",
                                    level: .error
                                )
                            }
                        }
                    case .background, .inactive:
                        didConnect = false
                        mqttClient.stopLoop()
                    @unknown default:
                        logger.log("Unknown case wtf", level: .error)
                        fatalError()
                    }
                }

        }
        .modelContainer(sharedModelContainer)
        .environmentObject(locationRecorder)
        .environmentObject(cameraManager)
        .environmentObject(imageRecognizerStore)
        .environmentObject(mqttClient)
        .environmentObject(earconEngine)
    }
}
