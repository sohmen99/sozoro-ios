import Foundation

public enum Kind: String, Codable, Sendable, CaseIterable {
    case food, culture

    public var labelEN: String { self == .food ? "Place to eat" : "Shrine, temple or landmark" }
    public var labelJA: String { self == .food ? "飲食店" : "文化財" }
    /// 集客力の見立て。混雑推定の層2。
    public var pop: Double { self == .food ? 0.24 : 0.32 }
}

public struct Spot: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let coordinate: Coordinate
    public let kind: Kind
    public let category: String
    /// 駅は帰り道なので、行き先とは別に扱う。
    public let isStation: Bool

    public init(id: String, name: String, coordinate: Coordinate,
                kind: Kind, category: String, isStation: Bool = false) {
        self.id = id; self.name = name; self.coordinate = coordinate
        self.kind = kind; self.category = category; self.isStation = isStation
    }
}

public struct Config: Sendable {
    /// m/分。不動産表記と同じ徒歩速度。
    public var walkSpeed = 80.0
    /// 実際の道のりは直線距離の約1.3倍。
    public var detour = 1.3
    /// 1区間は徒歩15分。時間は選ばせない。
    public var legMinutes = 15.0
    /// 距離帯の許容。前後7分。
    public var toleranceMinutes = 7.0
    /// これより近い候補は散歩にならない。
    public var minMetres = 250.0
    /// ここまで近づいたら到着。
    public var arrivalMetres = 60.0

    public init() {}

    /// 選んだ時間に対する直線距離。
    public func targetMetres(_ minutes: Double) -> Double { minutes * walkSpeed / detour }
    public var toleranceMetres: Double { toleranceMinutes * walkSpeed / detour }
    /// 直線距離から、道のりぶんを見込んだ徒歩の分。
    public func minutes(forStraight m: Double) -> Int { max(1, Int((m * detour / walkSpeed).rounded())) }
}
