import Foundation

enum DeviceType: String, Codable {
    case iOsApp = "IOsApp"
    case lillyGo = "LillyGo"
    case galaxyWatch = "GalaxyWatch"
}

struct LogData: Codable {
    let device: DeviceType
    let tag: String
    let data: String

    init(device: DeviceType, tag: String, data: String) {
        self.device = device
        self.tag = tag
        self.data = data
    }

    init<Payload: Encodable>(device: DeviceType, tag: String, payload: Payload) throws {
        self.init(
            device: device,
            tag: tag,
            data: String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
        )
    }

    func decodePayload<Payload: Decodable>(_ type: Payload.Type) throws -> Payload {
        try JSONDecoder().decode(type, from: Data(data.utf8))
    }
}
