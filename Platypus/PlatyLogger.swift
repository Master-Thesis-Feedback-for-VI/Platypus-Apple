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
    public func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let location = "\(tag) \(file):\(line) \(function)"
        switch level {
        case .debug:
            logger.debug("[[DEBUG]]: \(location, privacy: .public) \(message, privacy: .public)")
        case .info:
            logger.info("[[INFO]]: \(location, privacy: .public) \(message, privacy: .public)")
        case .warning:
            logger.warning("[[WARNING]]: \(location, privacy: .public) \(message, privacy: .public)")
        case .error:
            logger.error("[[ERROR]]: \(location, privacy: .public) \(message, privacy: .public)")
        }
    }
}
