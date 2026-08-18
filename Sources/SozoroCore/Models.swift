import Foundation

public enum Kind: String, Codable, Sendable, CaseIterable {
    // 行き先は185件の中だけ。公園・庭園は母集団に無いので気分にも置かない。
    case food, culture

    public var labelEN: String {
        self == .food ? "Place to eat" : "Shrine, temple or landmark"
    }
    public var labelJA: String { self == .food ? "飲食店" : "文化財" }
    /// 開いている時間。寺社と公園は門の外からでも成立するので、時間を持たない。
    public var openHours: (Int, Int)? { self == .food ? (8, 22) : nil }
    /// その時刻に行き先として成立するか。
    public func isOpen(at when: Date, calendar: Calendar = .current) -> Bool {
        guard let h = openHours else { return true }
        let hour = calendar.component(.hour, from: when)
        return h.0 <= h.1 ? (hour >= h.0 && hour < h.1) : (hour >= h.0 || hour < h.1)
    }

    /// 集客力の見立て。混雑推定の層2。手で置いた値が無いときだけ使う。
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
    /// 集客力（層2）を手で置いてあるとき。基準地点はこちらを使う。
    /// nil なら種類ごとの見立て（Kind.pop）に落ちる。
    public let pop: Double?
    /// 一日のかたち（層3）の引き当て。基準地点は種類が行き先と違うので、
    /// "green" や "shops" を直接渡せるようにしておく。nil なら種類のまま。
    public let curveKey: String?

    /// 混雑推定に使う集客力。
    public var popValue: Double { pop ?? kind.pop }
    /// 混雑推定に使う一日のかたちの名前。
    public var curveName: String { curveKey ?? kind.rawValue }

    public init(id: String, name: String, coordinate: Coordinate,
                kind: Kind, category: String, isStation: Bool = false,
                pop: Double? = nil, curveKey: String? = nil) {
        self.id = id; self.name = name; self.coordinate = coordinate
        self.kind = kind; self.category = category; self.isStation = isStation
        self.pop = pop; self.curveKey = curveKey
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
