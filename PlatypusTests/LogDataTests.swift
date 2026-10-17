import Foundation
import Testing
@testable import Platypus

struct LogDataTests {
    @Test func encodesPayloadAsJSONString() throws {
        let log = try LogData(
            device: .iOsApp,
            tag: AvailableTopics.hapticLeft.rawValue,
            payload: PlatyMQTT.SendMessage(increaseDiff: 5)
        )
        let encoded = try JSONEncoder().encode(log)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        #expect(object["device"] as? String == "IOsApp")
        #expect(object["tag"] as? String == "IoT/device/haptic_left")
        #expect(object["data"] as? String == "{\"increaseDiff\":5}")
        #expect(try log.decodePayload(PlatyMQTT.SendMessage.self).increaseDiff == 5)
    }

    @Test(arguments: ["IOsApp", "LillyGo", "GalaxyWatch"])
    func decodesRustEnvelope(device: String) throws {
        let json = #"{"device":"\#(device)","tag":"profile_swap","data":"{\"cmd\":1}"}"#
        let log = try JSONDecoder().decode(LogData.self, from: Data(json.utf8))

        #expect(log.device.rawValue == device)
        #expect(try log.decodePayload(PlatyMQTT.RecMessage.self).cmd == .next)
    }

    @Test func rejectsUnwrappedMessage() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LogData.self, from: Data(#"{"cmd":1}"#.utf8))
        }
    }

    @Test func rejectsObjectInsteadOfJSONString() {
        let json = #"{"device":"GalaxyWatch","tag":"profile_swap","data":{"cmd":1}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LogData.self, from: Data(json.utf8))
        }
    }

    @Test func rejectsInvalidInnerJSON() throws {
        let log = LogData(device: .lillyGo, tag: "profile_swap", data: "not JSON")
        #expect(throws: DecodingError.self) {
            try log.decodePayload(PlatyMQTT.RecMessage.self)
        }
    }
}
