import Foundation

/// 1回の散歩の記録。サーバーにアカウントは作らない。端末に貯める。
public struct Walk: Codable, Identifiable, Sendable {
    public var id: String
    public var startedAt: Date
    public var arrivedAt: Date
    public var straightM: Double
    /// 出発地よりどれだけ空いた場所へ出たか（0〜100）。人流誘導の成果そのもの。
    public var dispersion: Int
    public var destName: String
    public var destKind: Kind
    public var destArea: String
    public var destOutsideTaito: Bool
    public var hintsUsed: Int
    public var demo: Bool

    public init(id: String = UUID().uuidString, startedAt: Date, arrivedAt: Date,
                straightM: Double, dispersion: Int, destName: String, destKind: Kind,
                destArea: String, destOutsideTaito: Bool, hintsUsed: Int = 0, demo: Bool = false) {
        self.id = id; self.startedAt = startedAt; self.arrivedAt = arrivedAt
        self.straightM = straightM; self.dispersion = dispersion
        self.destName = destName; self.destKind = destKind; self.destArea = destArea
        self.destOutsideTaito = destOutsideTaito; self.hintsUsed = hintsUsed; self.demo = demo
    }
}

public struct WalkStats: Sendable {
    public var count = 0
    public var totalM = 0.0, maxM = 0.0
    public var maxDispersion = 0, totalDispersion = 0
    public var outside = 0, noHint = 0, dawn = 0, dusk = 0
    public var areas = 0, kinds = 0, days = 0

    public init(_ walks: [Walk], detour: Double = 1.3, calendar: Calendar = .current) {
        var a = Set<String>(), k = Set<Kind>(), d = Set<String>()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        for w in walks {
            count += 1
            totalM += w.straightM * detour
            maxM = max(maxM, w.straightM)
            maxDispersion = max(maxDispersion, w.dispersion)
            totalDispersion += w.dispersion
            if w.destOutsideTaito { outside += 1 }
            if w.hintsUsed == 0 { noHint += 1 }
            let h = calendar.component(.hour, from: w.arrivedAt)
            if h < 9 { dawn += 1 }
            if h >= 19 { dusk += 1 }
            if !w.destArea.isEmpty { a.insert(w.destArea) }
            k.insert(w.destKind)
            d.insert(f.string(from: w.arrivedAt))
        }
        areas = a.count; kinds = k.count; days = d.count
    }
}

/// 集めるもの。ウェブ版の15種をそのまま。名前は旅の言葉で揃えてある。
public struct Reward: Identifiable, Sendable {
    public let id: String
    public let symbol: String
    public let title: String
    public let condition: String
    /// 日本語。ウェブ版の REWARDS が ja / cja で持っているのと同じ。
    public let titleJA: String
    public let conditionJA: String
    public let test: @Sendable (WalkStats) -> Bool

    public func title(_ lang: Lang) -> String { lang == .ja ? titleJA : title }
    public func condition(_ lang: Lang) -> String { lang == .ja ? conditionJA : condition }

    public static let all: [Reward] = [
        .init(id: "first",   symbol: "shoeprints.fill",   title: "First step",
              condition: "Arrived once",
              titleJA: "はじめの一歩", conditionJA: "1回 着いた") { $0.count >= 1 },
        .init(id: "three",   symbol: "arrow.triangle.branch", title: "Three turns",
              condition: "Three walks",
              titleJA: "三度の角", conditionJA: "3回 歩いた") { $0.count >= 3 },
        .init(id: "ten",     symbol: "seal",              title: "Ten stamps",
              condition: "Ten walks",
              titleJA: "十の印", conditionJA: "10回 歩いた") { $0.count >= 10 },
        .init(id: "cross",   symbol: "point.topleft.down.to.point.bottomright.curvepath",
              title: "Over the line", condition: "Arrived outside Taito",
              titleJA: "区をこえて", conditionJA: "台東区の外に 着いた") { $0.outside >= 1 },
        .init(id: "areas3",  symbol: "map",               title: "Three towns",
              condition: "Three different areas",
              titleJA: "三つの町", conditionJA: "3つの地区に 着いた") { $0.areas >= 3 },
        .init(id: "areas5",  symbol: "safari",            title: "Five towns",
              condition: "Five different areas",
              titleJA: "五つの町", conditionJA: "5つの地区に 着いた") { $0.areas >= 5 },
        .init(id: "ri",      symbol: "mountain.2",        title: "One ri",
              condition: "4 km in total",
              titleJA: "一里", conditionJA: "のべ4km 歩いた") { $0.totalM >= 4000 },
        .init(id: "far",     symbol: "flag",              title: "Long haul",
              condition: "2 km out in one walk",
              titleJA: "遠出", conditionJA: "1回で2km 出た") { $0.maxM >= 2000 },
        .init(id: "against", symbol: "wind",              title: "Against the flow",
              condition: "40 points quieter than the start",
              titleJA: "人波の逆へ", conditionJA: "出発地より40ポイント 空いた場所へ") { $0.maxDispersion >= 40 },
        .init(id: "ebb",     symbol: "water.waves",       title: "Ebb tide",
              condition: "300 dispersion points",
              titleJA: "引き潮", conditionJA: "分散ポイント300") { $0.totalDispersion >= 300 },
        .init(id: "blind",   symbol: "eye.slash",         title: "No hints",
              condition: "Arrived without a hint",
              titleJA: "ヒント無し", conditionJA: "ヒント無しで 着いた") { $0.noHint >= 1 },
        .init(id: "dawn",    symbol: "sunrise",           title: "Morning walker",
              condition: "Arrived before 9",
              titleJA: "朝の人", conditionJA: "9時前に 着いた") { $0.dawn >= 1 },
        .init(id: "dusk",    symbol: "moon.stars",        title: "Night walker",
              condition: "Arrived after 19",
              titleJA: "夜の人", conditionJA: "19時すぎに 着いた") { $0.dusk >= 1 },
        // 気分は2つ。みどりを外したので、3つは永久に埋まらない。
        .init(id: "both",    symbol: "square.grid.2x2",   title: "Both moods",
              condition: "Arrived on food and on something old",
              titleJA: "二つの気分", conditionJA: "2つの気分どちらでも 着いた") { $0.kinds >= 2 },
        .init(id: "regular", symbol: "calendar",          title: "Regular",
              condition: "Walked on three days",
              titleJA: "常連", conditionJA: "3日に分けて 歩いた") { $0.days >= 3 }
    ]

    public static func earned(_ walks: [Walk]) -> Set<String> {
        let s = WalkStats(walks)
        return Set(all.filter { $0.test(s) }.map(\.id))
    }
}

/// 端末に貯める。アカウントは作らない。ウェブ版の localStorage にあたる。
public final class WalkLog: @unchecked Sendable {
    public static let shared = WalkLog()
    private let key = "sozoro.walks.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var walks: [Walk] {
        guard let d = defaults.data(forKey: key),
              let v = try? JSONDecoder().decode([Walk].self, from: d) else { return [] }
        return v
    }
    public func add(_ w: Walk) {
        var all = walks; all.append(w)
        if let d = try? JSONEncoder().encode(all) { defaults.set(d, forKey: key) }
    }
    public func clear() { defaults.removeObject(forKey: key) }
    public var earned: Set<String> { Reward.earned(walks) }
    public var visitedNames: Set<String> { Set(walks.map(\.destName)) }
}
