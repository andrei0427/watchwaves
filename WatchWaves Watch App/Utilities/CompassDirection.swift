import Foundation

enum CompassDirection: String, CaseIterable, Codable, Identifiable {
    case north = "N"
    case northEast = "NE"
    case east = "E"
    case southEast = "SE"
    case south = "S"
    case southWest = "SW"
    case west = "W"
    case northWest = "NW"

    var id: String { rawValue }

    var bearing: Double {
        switch self {
        case .north: 0
        case .northEast: 45
        case .east: 90
        case .southEast: 135
        case .south: 180
        case .southWest: 225
        case .west: 270
        case .northWest: 315
        }
    }

    var label: String {
        switch self {
        case .north: "North"
        case .northEast: "Northeast"
        case .east: "East"
        case .southEast: "Southeast"
        case .south: "South"
        case .southWest: "Southwest"
        case .west: "West"
        case .northWest: "Northwest"
        }
    }

    var sfSymbol: String {
        switch self {
        case .north: "arrow.up"
        case .northEast: "arrow.up.right"
        case .east: "arrow.right"
        case .southEast: "arrow.down.right"
        case .south: "arrow.down"
        case .southWest: "arrow.down.left"
        case .west: "arrow.left"
        case .northWest: "arrow.up.left"
        }
    }

    /// Opposite direction (where waves come FROM if ocean is in this direction)
    var opposite: CompassDirection {
        switch self {
        case .north: .south
        case .northEast: .southWest
        case .east: .west
        case .southEast: .northWest
        case .south: .north
        case .southWest: .northEast
        case .west: .east
        case .northWest: .southEast
        }
    }

    /// Initialize from a bearing angle (0-360)
    static func from(bearing: Double) -> CompassDirection {
        let normalized = ((bearing.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int(round(normalized / 45)) % 8
        return allCases[index]
    }
}
