import Foundation
import MetaCodable
import HelperCoders

// MARK: - Duration
// Mirrors Rust's std::time::Duration { secs: u64, nanos: u32 } (0 <= nanos < 1_000_000_000)
@Codable
@MemberInit
struct IFDuration {
    @CodedAt("secs")
    var secs: UInt64
    @CodedAt("nanos")
    var nanos: UInt32
}

// MARK: - Coordinate
@Codable
@MemberInit
struct IFCoordinate: Hashable {
    var lat: Double
    var lon: Double
}

// MARK: - ContextCategory
// Rust: #[derive(... Hash, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
// Unit-only enum -> serde serializes as a plain string, matching @CodedAs per case.
@Codable
enum IFContextCategory: String, Hashable, Comparable {
    @CodedAs("Forest")
    case forest

    @CodedAs("Outside")
    case outside
    @CodedAs("Inside")
    case inside

    @CodedAs("Street")
    case street
    @CodedAs("Pedestrian")
    case pedestrian
    @CodedAs("Intersection")
    case intersection

    @CodedAs("Elevator")
    case elevator

    static func < (lhs: IFContextCategory, rhs: IFContextCategory) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    // Preserves the declaration order of the Rust enum for Ord/PartialOrd parity.
    private var sortOrder: Int {
        switch self {
        case .forest: return 0
        case .outside: return 1
        case .inside: return 2
        case .street: return 3
        case .pedestrian: return 4
        case .intersection: return 5
        case .elevator: return 6
        }
    }
}

// MARK: - DetectionType
// Rust: unit variants encode as bare strings; the one tuple variant `Unknown(String)`
// encodes externally-tagged as {"Unknown": "<value>"}. MetaCodable's default enum
// strategy for mixed unit/associated-value cases reproduces this external tagging.
@Codable
enum IFDetectionType: Equatable {
    @CodedAs("Person")
    case person
    @CodedAs("TrafficLight")
    case trafficLight
    @CodedAs("Car")
    case car
    @CodedAs("Bicycle")
    case bicycle
    @CodedAs("Bench")
    case bench
    @CodedAs("Chair")
    case chair
    @CodedAs("DiningTable")
    case diningTable

    @CodedAs("Unknown")
    case unknown(String)
}

// MARK: - Detection
@Codable
@MemberInit
struct IFDetection {
    var confidence: Float
    var name: IFDetectionType
}

// MARK: - ImageDetections
@Codable
@MemberInit
struct IFImageDetections {
    var detections: [IFDetection] = []
}

// MARK: - UniqueGeographicCategories
@Codable
@MemberInit
struct IFUniqueGeographicCategories {
    var detections: IFImageDetections? = nil

    @Default([])
    var categories: Set<IFContextCategory> = []

    @Default(false)
    @CodedAt("is_inside")
    var isInside: Bool = false
}

// MARK: - CategoryTime
// Rust struct only derives Serialize (no Deserialize), so this is encode-only in Swift too.
@Codable
@MemberInit
struct IFCategoryTime {
    var categories: IFUniqueGeographicCategories
    @CodedAt("time_diff")
    var timeDiff: IFDuration
    var location: IFCoordinate
}
