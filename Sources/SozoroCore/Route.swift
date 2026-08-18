import Foundation

/// 向こうまで抜けるモード。方角を決めて駅を終点にし、道筋を文化財で割る。
/// 着いたら電車で帰れるので、途中で「まだ続けるか」を聞かなくていい。
public struct Route: Sendable {
    public struct Direction: Sendable, Equatable {
        public let key: String, en: String, ja: String
    }
    public static let directions: [Direction] = [
        .init(key: "N",  en: "North",      ja: "北"),   .init(key: "NE", en: "North-east", ja: "北東"),
        .init(key: "E",  en: "East",       ja: "東"),   .init(key: "SE", en: "South-east", ja: "南東"),
        .init(key: "S",  en: "South",      ja: "南"),   .init(key: "SW", en: "South-west", ja: "南西"),
        .init(key: "W",  en: "West",       ja: "西"),   .init(key: "NW", en: "North-west", ja: "北西")
    ]

    public struct Option: Sendable {
        public let direction: Direction
        public let station: Spot
        public let metres: Double
        public let minutes: Int
        /// 実際の方位。方角の名前は45度刻みだが、記号はこちらで回す。
        public let bearing: Double
    }

    public struct Course: Sendable {
        public let stops: [Spot]
        public let station: Spot
        public let direction: Direction
        public let totalMinutes: Int
        public var index: Int = 0
        public var remaining: Int { max(0, stops.count - 1 - index) }
    }

    public let config: Config
    let data: SozoroData
    public init(config: Config = Config(), data: SozoroData = .shared) {
        self.config = config; self.data = data
    }

    /// 中に入れないもの、置いてあるだけのものは道筋に置かない。
    static let notVisitable = try! NSRegularExpression(
        pattern: "非公開|手水鉢|狛犬|力石|水盤|天水桶|石灯籠|石燈籠|燈籠|灯籠|庚申塔|板碑|石造物群|石碑群|石像|所蔵|文書|絵図|絵巻")
    static func visitable(_ name: String) -> Bool {
        notVisitable.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) == nil
    }

    /// その方角にある、歩いて手ごろな距離の駅。近すぎても遠すぎても散歩にならない。
    public func options(from origin: Coordinate) -> [Option] {
        var best: [String: Option] = [:]
        for (i, d) in Self.directions.enumerated() {
            var pick: Option?
            for st in data.stations {
                let m = Geo.distance(origin, st.coordinate)
                guard m >= 1300, m <= 3800 else { continue }
                let b = Geo.bearing(origin, st.coordinate)
                let off = abs((b - Double(i) * 45 + 180).truncatingRemainder(dividingBy: 360) + 360)
                            .truncatingRemainder(dividingBy: 360) - 180
                guard abs(off) <= 26 else { continue }
                if pick == nil || m < pick!.metres {
                    pick = Option(direction: d, station: st, metres: m,
                                  minutes: config.minutes(forStraight: m), bearing: b)
                }
            }
            // 同じ駅が隣り合う方角に二度出る。いちばん素直な向きだけ残す。
            if let p = pick {
                let off = abs((Geo.bearing(origin, p.station.coordinate) - Double(i) * 45 + 180)
                            .truncatingRemainder(dividingBy: 360) + 360)
                            .truncatingRemainder(dividingBy: 360) - 180
                if let cur = best[p.station.name] {
                    let curIdx = Self.directions.firstIndex(of: cur.direction)!
                    let curOff = abs((Geo.bearing(origin, cur.station.coordinate) - Double(curIdx) * 45 + 180)
                                .truncatingRemainder(dividingBy: 360) + 360)
                                .truncatingRemainder(dividingBy: 360) - 180
                    if abs(off) >= abs(curOff) { continue }
                }
                best[p.station.name] = p
            }
        }
        // 途中に寄る場所が見つからず、長い一本道になってしまう行き先は出さない。
        let limit = config.legMinutes + config.toleranceMinutes + 1
        return best.values
            .filter { opt in
                var from = origin
                for s in build(from: origin, to: opt).stops {
                    if Double(config.minutes(forStraight: Geo.distance(from, s.coordinate))) > limit { return false }
                    from = s.coordinate
                }
                return true
            }
            .sorted { Self.directions.firstIndex(of: $0.direction)! < Self.directions.firstIndex(of: $1.direction)! }
    }

    /// 出発地から駅までを15分ずつに割り、割れ目のいちばん近い文化財を寄り道にする。
    public func build(from origin: Coordinate, to opt: Option) -> Course {
        let legs = max(1, min(3, Int(ceil(Double(opt.minutes) / (config.legMinutes + config.toleranceMinutes)))))
        var stops: [Spot] = []
        var used = Set<String>()
        if legs > 1 {
            for i in 1..<legs {
                let f = Double(i) / Double(legs)
                let at = Coordinate(lat: origin.lat + (opt.station.coordinate.lat - origin.lat) * f,
                                    lon: origin.lon + (opt.station.coordinate.lon - origin.lon) * f)
                var best: (Spot, Double)?
                for c in data.culture where !used.contains(c.id) && Self.visitable(c.name) {
                    let d = Geo.distance(at, c.coordinate)
                    guard d <= 500 else { continue }
                    if best == nil || d < best!.1 { best = (c, d) }
                }
                if let b = best { used.insert(b.0.id); stops.append(b.0) }
            }
        }
        stops.append(opt.station)
        return Course(stops: stops, station: opt.station, direction: opt.direction,
                      totalMinutes: opt.minutes)
    }
}
