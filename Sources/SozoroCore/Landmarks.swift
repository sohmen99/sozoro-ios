import Foundation

/// 地図に出す基準地点。行き先ではなく「混雑の可視化」のために置いている。
public struct Landmark: Identifiable, Sendable, Codable {
    public let id: String
    public let lat: Double
    public let lon: Double
    /// ウェブ版と同じアイコンの名前（i-pagoda など）。
    public let icon: String
    public let kind: String
    /// その場所の集客力。混雑推定の層2。
    public let pop: Double
    public let en: String
    public let ja: String

    public var coordinate: Coordinate { Coordinate(lat: lat, lon: lon) }

    /// 混雑推定に渡すための見立て。
    public var asSpot: Spot {
        Spot(id: "lm/" + id, name: en, coordinate: coordinate,
             kind: kind == "food" ? .food : .culture, category: kind,
             // 集客力もかたちも、手で置いた値をそのまま渡す。
             // 種類に丸めると浅草寺が 100 ではなく 51 になる。
             pop: pop, curveKey: kind)
    }

    public static let all: [Landmark] = {
        guard let url = Bundle.module.url(forResource: "landmarks", withExtension: "json"),
              let d = try? Data(contentsOf: url),
              let v = try? JSONDecoder().decode([Landmark].self, from: d) else { return [] }
        return v
    }()
}

/// ウェブ版の線画アイコン。24×24 の viewBox のまま持ってきて、必要な大きさに伸ばす。
public struct IconShape: Sendable, Codable {
    public struct Circle: Sendable, Codable { public let cx, cy, r: Double }
    public struct Rect: Sendable, Codable { public let w, h, x, y, rx: Double }
    public struct Line: Sendable, Codable { public let x1, x2, y1, y2: Double }
    public let paths: [String]
    public let circles: [Circle]
    public let rects: [Rect]
    public let lines: [Line]

    public static let all: [String: IconShape] = {
        guard let url = Bundle.module.url(forResource: "icons", withExtension: "json"),
              let d = try? Data(contentsOf: url),
              let v = try? JSONDecoder().decode([String: IconShape].self, from: d) else { return [:] }
        return v
    }()
}

extension Crowd {
    /// 一日のかたち。詳細表示のグラフに使う。
    public func day(_ spot: Spot, on when: Date, calendar: Calendar = .current) -> [Int] {
        var out: [Int] = []
        var c = calendar.dateComponents([.year, .month, .day], from: when)
        for h in 0..<24 {
            c.hour = h; c.minute = 0
            out.append(level(spot, at: calendar.date(from: c) ?? when, calendar: calendar))
        }
        return out
    }

    /// これから空きはじめる時刻。無ければ nil。
    public func clearsAt(_ spot: Spot, from when: Date, calendar: Calendar = .current) -> Int? {
        let h = calendar.component(.hour, from: when)
        guard h < 22 else { return nil }
        let d = day(spot, on: when, calendar: calendar)
        for t in (h + 1)...22 where d[t] < 45 { return t }
        return nil
    }

    public enum Level: String, Sendable { case quiet, mid, busy }
    public static func band(_ v: Int) -> Level { v < 40 ? .quiet : (v < 70 ? .mid : .busy) }
}
