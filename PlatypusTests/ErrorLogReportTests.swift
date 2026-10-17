import Foundation
import Testing
@testable import Platypus

struct ErrorLogReportTests {
    @Test func encodesErrorInMQTTEnvelope() throws {
        let report = LogData(
            device: .iOsApp,
            tag: "ImageRecognizerStore",
            data: "[[ERROR]]: ImageRecognizerStore failed to load"
        )
        let encoded = try JSONEncoder().encode(report)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        #expect(AvailableTopics.telemetryReport.rawValue == "telemetry/report")
        #expect(object["device"] as? String == "IOsApp")
        #expect(object["tag"] as? String == "ImageRecognizerStore")
        #expect(object["data"] as? String == report.data)
    }
}
