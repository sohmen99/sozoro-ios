import Foundation

/// 抽選。argmax ではなく重みつきランダムなので、同じ条件でも毎回ちがう。
public struct Draw: Sendable {
    public let config: Config
    public let crowd: Crowd

    public init(config: Config = Config(), crowd: Crowd = Crowd()) {
        self.config = config; self.crowd = crowd
    }

    /// 推したいエリア。静けさだけで選ぶと「ただ空いているだけ」の場所が出る。
    public struct Favoured: Sendable {
        public let name: String, coordinate: Coordinate, radius: Double, boost: Double
        public init(name: String, coordinate: Coordinate, radius: Double, boost: Double) {
            self.name = name; self.coordinate = coordinate; self.radius = radius; self.boost = boost
        }
    }
    public static let favoured = [
        Favoured(name: "谷中", coordinate: .init(lat: 35.7276, lon: 139.7663), radius: 900, boost: 2.4)
    ]

    public struct Context: Sendable {
        public var origin: Coordinate
        public var kinds: Set<Kind>
        public var visited: Set<String>
        public var now: Date
        /// あてもなく歩くときは、混んでいる場所を **一件も引かない**。
        /// 静けさの重みは掛け算なので、確率は下がっても 0 にはならない。
        /// 人を混雑から逃がすのが目的である以上、ここは掛け算ではなく門にする。
        /// 駅まで抜けるコースは通り道なので、この門は掛けない。
        public var avoidCrowded: Bool
        /// いま混んでいる核の座標。avoidCrowded のときだけ見る。
        public var cores: [Coordinate]
        public init(origin: Coordinate, kinds: Set<Kind> = Set(Kind.allCases),
                    visited: Set<String> = [], now: Date = Date(),
                    avoidCrowded: Bool = true, cores: [Coordinate] = []) {
            self.origin = origin; self.kinds = kinds; self.visited = visited
            self.now = now; self.avoidCrowded = avoidCrowded; self.cores = cores
        }
    }

    /// これ以上は「混んでいる」。地図の凡例の紫と同じ境。
    public static let crowdedFrom = 70
    /// 混んでいる核から、この距離までは「混雑エリア」とみなす。
    /// 地図で紫ににじんでいる範囲と、だいたい同じ。
    public static let crowdedRadius = 500.0

    /// いま混んでいる核。時刻で変わる。深夜はどこも混んでいないので空になる。
    public func crowdedCores(at when: Date) -> [Coordinate] {
        Landmark.all.filter { crowd.level($0.asSpot, at: when) >= Self.crowdedFrom }
            .map(\.coordinate)
    }

    public var target: Double { config.targetMetres(config.legMinutes) }
    public var tolerance: Double { config.toleranceMetres }
    public var searchRadius: Double { target + tolerance * 2.4 }

    /// 1件の重み。0 なら引かれない。
    public func weight(_ spot: Spot, _ ctx: Context, tolerance tol: Double? = nil) -> Double {
        let tol = tol ?? tolerance
        let d = Geo.distance(ctx.origin, spot.coordinate)
        guard d >= config.minMetres, !ctx.visited.contains(spot.id), ctx.kinds.contains(spot.kind),
              spot.kind.isOpen(at: ctx.now)
        else { return 0 }

        // 1 · 帯の外は 0。なだらかな山だけだと、外側の輪ほど候補が多いので合計で勝ってしまう。
        let off = (d - target) / tol
        guard off >= -1, off <= 1 else { return 0 }
        let band = exp(-off * off)

        // 2 · 静けさ。混んでいる所は、そもそも引かない。
        //     あてもなく歩くときは掛け算ではなく門にする。静けさの重みは確率を
        //     下げるだけで 0 にはしないので、人を混雑から逃がすには足りない。
        let level = crowd.level(spot, at: ctx.now)
        if ctx.avoidCrowded {
            if level >= Self.crowdedFrom { return 0 }
            for c in ctx.cores where Geo.distance(spot.coordinate, c) <= Self.crowdedRadius {
                return 0
            }
        }
        let quiet = pow(Double(100 - level) / 100, 2.2)

        // 3 · 外向き。人出の多い帯から少ない帯へ送り出す。実測がそのまま効く。
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: ctx.now)
        let outward = 0.22 + 0.78 * (1 - crowd.footfall(at: spot.coordinate, weekend: wd == 1 || wd == 7))

        // 4 · 推しエリアの上乗せ。
        var favour = 1.0
        for f in Self.favoured where Geo.distance(spot.coordinate, f.coordinate) <= f.radius {
            favour = max(favour, f.boost)
        }
        return band * quiet * outward * favour
    }

    /// 重みつきで1件。
    public func pick(_ spots: [Spot], _ ctx: Context, tolerance tol: Double? = nil,
                     using rng: inout some RandomNumberGenerator) -> Spot? {
        var scored: [(Spot, Double)] = []
        var total = 0.0
        for s in spots {
            let w = weight(s, ctx, tolerance: tol)
            if w > 0 { scored.append((s, w)); total += w }
        }
        guard total > 0 else { return nil }
        var r = Double.random(in: 0..<total, using: &rng)
        for (s, w) in scored { r -= w; if r <= 0 { return s } }
        return scored.last?.0
    }

    /// 重複なしで n 件。3枚そろわなければ帯を広げ、広げた分を返す。
    public func pickMany(_ spots: [Spot], _ ctx: Context, count: Int = 3,
                         using rng: inout some RandomNumberGenerator) -> (picks: [Spot], widenedMinutes: Int) {
        for step in [1.0, 1.6, 2.4] {
            var pool = spots, out: [Spot] = []
            var c = ctx
            for _ in 0..<count {
                guard let got = pick(pool, c, tolerance: tolerance * step, using: &rng) else { break }
                out.append(got)
                c.visited.insert(got.id)
                pool.removeAll { $0.id == got.id }
            }
            if out.count >= count {
                return (out, step == 1 ? 0 : Int((config.toleranceMinutes * step).rounded()))
            }
            if step == 2.4 { return (out, Int((config.toleranceMinutes * step).rounded())) }
        }
        return ([], 0)
    }

    /// 半径内の候補。
    public func candidates(from data: SozoroData = .shared, _ ctx: Context) -> [Spot] {
        data.spots.filter {
            ctx.kinds.contains($0.kind) && Geo.distance(ctx.origin, $0.coordinate) <= searchRadius
        }
    }
}
