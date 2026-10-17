//
//  PlatyLogger.swift
//  Platypus
//
//  Created by Yann Bernard on 15.09.26.
//

import Foundation
import MQTTNIO
import os

var MINIMUM_LOG_LEVEL: PlatyLogger.LogLevel = .warning

struct PlatyLogger {
    static weak var mqttClient: PlatyMQTT?

    let tag: String
    private let logger: Logger

    enum LogLevel: Comparable {
        case debug
        case info
        case warning
        case error
    }

    init(tag: String) {
        self.tag = tag
        let subsystem = DOMAIN
        self.logger = Logger(subsystem: subsystem, category: tag)
    }
}

extension PlatyLogger {
    public func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard MINIMUM_LOG_LEVEL <= level else {
            return
        }
        
        let location = "\(tag) \(file):\(line) \(function)"
        switch level {
        case .debug:
            logger.debug(
                "[[DEBUG]]: \(location, privacy: .public) \(message, privacy: .public)"
            )
        case .info:
            logger.info(
                "[[INFO]]: \(location, privacy: .public) \(message, privacy: .public)"
            )
        case .warning:
            logger.warning(
                "[[WARNING]]: \(location, privacy: .public) \(message, privacy: .public)"
            )
        case .error:
            logger.error(
                "[[ERROR]]: \(location, privacy: .public) \(message, privacy: .public)"
            )
            let report = LogData(
                device: .iOsApp,
                tag: tag,
                data: "[[ERROR]]: \(location) \(message)"
            )
            Task {
                guard let mqttClient = Self.mqttClient,
                    mqttClient.connectionStatus == .connected
                else { return }
                try? await mqttClient.publish(
                    to: .telemetryReport,
                    logData: report,
                    qos: .atMostOnce
                )
            }
        }
    }
}
