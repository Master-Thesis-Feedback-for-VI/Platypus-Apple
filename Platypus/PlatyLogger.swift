//
//  PlatyLogger.swift
//  Platypus
//
//  Created by Yann Bernard on 15.09.26.
//

import Foundation
import os

struct PlatyLogger {
    let tag: String
    private let logger: Logger

    enum LogLevel {
        case debug, info, warning, error
    }

    init(tag: String) {
        self.tag = tag
        let subsystem = DOMAIN
        self.logger = Logger(subsystem: subsystem, category: tag)
    }
}

extension PlatyLogger {
    public func log(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug:
            let prependTag = "[[DEBUG]]"
            logger.debug("\(prependTag):  \(message, privacy: .public)")
        case .info:
            let prependTag = "[[INFO]]"
            logger.info("\(prependTag):  \(message, privacy: .public)")
        case .warning:
            let prependTag = "[[WARNING]]"
            logger.warning("\(prependTag):  \(message, privacy: .public)")
        case .error:
            let prependTag = "[[ERROR]]"
            logger.error("\(prependTag):  \(message, privacy: .public)")
        }
    }
}
