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
import SwiftUI

final class PlatyMQTT: ObservableObject {
    @Published var lastRecMessage: RecMessage? = nil
    @Published var connectionStatus: ConnectionStatus = .disconnected

    private let client: MQTTClient
    private let logger = PlatyLogger(tag: "PlatyMQTT")
    private var toSubscribe: [MQTTSubscribeInfo] = []
    private var loopTask: Task<Void, Error>?

    var subsToCallbacks:
        [AvailableTopics: [Namespace.ID: [(RecMessage) -> Void]]] = [:]

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

    struct SendMessage: Codable {
        let increaseDiff: Int
    }
}

extension PlatyMQTT {
    enum ConnectionStatus {
        case disconnected, connected, establishing
    }
}

extension PlatyMQTT {
    func subscribeToTopics(to topics: AvailableTopics..., qos: MQTTQoS = .atMostOnce) async throws {
        for topic in topics {
            self.subscribe(to: topic, qos: .atLeastOnce)
        }

        self.connectionStatus = .establishing
        do {
            _ = try await self.client.connect()
            self.connectionStatus = .connected
        } catch {
            self.connectionStatus = .disconnected
            throw error
        }
    }

    func subscribe(to topic: AvailableTopics, qos: MQTTQoS) {
        let subscription = MQTTSubscribeInfo(
            topicFilter: topic.rawValue,
            qos: qos
        )
        toSubscribe.append(subscription)
    }

    func addCallback(
        topic: AvailableTopics,
        namespace: Namespace.ID,
        cb: @escaping (RecMessage) -> Void
    ) {
        subsToCallbacks[topic, default: [:]][namespace, default: []].append(cb)
    }

    func publish(
        to topic: AvailableTopics,
        payload: SendMessage,
        qos: MQTTQoS = .atLeastOnce
    ) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let byteBuffer = ByteBuffer(bytes: data)

        try await client.publish(
            to: topic.rawValue,
            payload: byteBuffer,
            qos: qos
        )
    }

    func startLoop() {
        if loopTask != nil {
            return
        }

        loopTask = Task.detached(priority: .background) {
            try await self.mainLoop()
        }
    }

    func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func flushCallbacks(namespace: Namespace.ID) {
        for topic in Array(subsToCallbacks.keys) {
            subsToCallbacks[topic]?[namespace] = nil
            if subsToCallbacks[topic]?.isEmpty == true {
                subsToCallbacks[topic] = nil
            }
        }
    }

    func flushAllCallbacks() {
        subsToCallbacks = [:]
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
                    let topic = AvailableTopics(rawValue: pub.topicName)!
                    let msgStr = String(buffer: pub.payload)
                    guard let data = msgStr.data(using: .utf8) else { continue }

                    do {
                        let msg = try decoder.decode(
                            RecMessage.self,
                            from: data
                        )
                        lastRecMessage = msg

                        subsToCallbacks[topic]?.values.joined().forEach {
                            $0(msg)
                        }
                    } catch {
                        logger.log(
                            "Failed to deserialize: \(error)\nwith data: \(msgStr)",
                            level: .error
                        )
                    }

                case .failure(let err):
                    logger.log("Failed to rec: \(err)", level: .error)
                }
            }
        } onCancel: {
            Task {
                do {
                    try await self.client.disconnect()
                } catch {
                    await logger.log("fail on cancel: \(error)")
                }
            }
        }
    }
}

enum AvailableTopics: String, CaseIterable {
    case hapticLeft = "IoT/device/haptic_left"
    case hapticRight = "IoT/device/haptic_right"
    case profileSwap = "IoT/device/profile_swap"
}
