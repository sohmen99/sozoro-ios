import Foundation

/// 緯度経度のひと組。CoreLocation に依存させないので、テストが素で回る。
public struct Coordinate: Equatable, Codable, Sendable {
    public var lat: Double
    public var lon: Double
    public init(lat: Double, lon: Double) { self.lat = lat; self.lon = lon }
}

public enum Geo {
    static let earthRadius = 6_371_000.0

    /// 2点の直線距離（m）。ウェブ版の distanceM と同じ半正矢式。
    public static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let la1 = a.lat * .pi / 180, la2 = b.lat * .pi / 180
        let s = sin(dLat / 2) * sin(dLat / 2)
              + sin(dLon / 2) * sin(dLon / 2) * cos(la1) * cos(la2)
        return 2 * earthRadius * asin(min(1, sqrt(s)))
    }

    /// a から見た b の方位（度・北0・時計回り）。
    public static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let la1 = a.lat * .pi / 180, la2 = b.lat * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let y = sin(dLon) * cos(la2)
        let x = cos(la1) * sin(la2) - sin(la1) * cos(la2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// 方位から進んだ先。デモの自動歩行で使う。
    public static func move(from p: Coordinate, bearing b: Double, metres d: Double) -> Coordinate {
        let ang = d / earthRadius, br = b * .pi / 180
        let la1 = p.lat * .pi / 180, lo1 = p.lon * .pi / 180
        let la2 = asin(sin(la1) * cos(ang) + cos(la1) * sin(ang) * cos(br))
        let lo2 = lo1 + atan2(sin(br) * sin(ang) * cos(la1), cos(ang) - sin(la1) * sin(la2))
        return Coordinate(lat: la2 * 180 / .pi, lon: lo2 * 180 / .pi)
    }

    public static let compassJA = ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]
    public static let compassEN = ["north", "north-east", "east", "south-east",
                            "south", "south-west", "west", "north-west"]

    public static func compassIndex(_ deg: Double) -> Int {
        Int((deg.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) / 45 + 0.5) % 8
    }
}
