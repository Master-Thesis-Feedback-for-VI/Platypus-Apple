//
//  PlatyMQTT.swift
//  Platypus
//
//  Created by Yann Bernard on 25.09.26.
//

import Combine
import Foundation
import MQTTNIO
internal import NIOCore
import NIOPosix
import NIOTransportServices

@MainActor
final class PlatyMQTT: ObservableObject {
    @Published var lastRecMessage: RecMessage? = nil
    @Published var connectionStatus: ConnectionStatus = .disconnected

    private let client: MQTTClient
    private let logger = PlatyLogger(tag: "PlatyMQTT")
    private var toSubscribe: [MQTTSubscribeInfo] = []
    private var loopTask: Task<Void, Error>?

    var subscriptions: [String: [(RecMessage) -> Void]] = [:]

    init(
        userName: String,
        passwd: String,
        hostname: String = "mqtt.yannbernard.com",
        port: UInt = 443,
        identifier: String = "Platypus-iOS-\(UUID().uuidString)",
        useSSL: Bool = true,
        useWebSockets: Bool = true,
    ) {
        self.client = MQTTClient(
            host: hostname,
            port: Int(port),
            identifier: identifier,
            eventLoopGroupProvider: .shared(NIOTSEventLoopGroup.singleton),
            configuration: .init(
                userName: userName,
                password: passwd,
                useSSL: useSSL,
                useWebSockets: useWebSockets,
                webSocketURLPath: "/"
            )
        )
    }
}

extension PlatyMQTT {
    enum RecMessageVariants: Int, Codable {
        case prev = 0
        case next = 1
        case empty = 2
    }

    struct RecMessage: Codable {
        let cmd: RecMessageVariants
    }

    enum ConnectionStatus {
        case disconnected, connected, establishing
    }
}

extension PlatyMQTT {
    func connect()
        async throws
    {
        self.connectionStatus = .establishing
        let success = try await self.client.connect(cleanSession: true)
        if success {
            self.connectionStatus = .connected
        } else {
            self.connectionStatus = .disconnected
        }
    }

    func addSubscription(
        topic: String,
        qos: MQTTQoS = .atLeastOnce,
        action: @escaping (RecMessage) -> Void
    ) {
        let subscription = MQTTSubscribeInfo(topicFilter: topic, qos: qos)
        toSubscribe.append(subscription)

        let some = subscriptions[topic]
        if var callbacks = some {
            callbacks.append(action)
            subscriptions[topic] = callbacks
        } else {
            subscriptions[topic] = [action]
        }
    }

    func startLoop() {
        if loopTask != nil {
            return
        }

        loopTask = Task.detached(priority: .background) {
            try await self.mainLoop()
        }
    }

    func stopLoop(flushCallbacks: Bool = true) {
        loopTask?.cancel()
        loopTask = nil

        if flushCallbacks {
            subscriptions = [:]
        }
    }

    private func mainLoop() async throws {
        defer { connectionStatus = .disconnected }

        let _ = try await client.subscribe(to: toSubscribe)
        let listener = client.createPublishListener()
        toSubscribe = []

        let decoder = JSONDecoder()

        await withTaskCancellationHandler {
            for await res in listener {
                if Task.isCancelled { break }

                switch res {
                case .success(let pub):
                    let topic = pub.topicName
                    let msgStr = String(buffer: pub.payload)
                    guard let data = msgStr.data(using: .utf8) else { continue }

                    do {
                        let msg = try decoder.decode(
                            RecMessage.self,
                            from: data
                        )
                        lastRecMessage = msg

                        if let callbacks = subscriptions[topic] {
                            for callback in callbacks {
                                callback(msg)
                            }
                        }
                    } catch {
                        logger.log("Failed to deserialize: \(error)")
                    }

                case .failure(let err):
                    logger.log("Failed to rec: \(err)", level: .error)
                }
            }
        } onCancel: {
            Task { try? await self.client.disconnect() }
        }
    }
}
