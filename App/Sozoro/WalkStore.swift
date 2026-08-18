import Foundation
import SozoroCore

/// 歩いている最中の状態をひとつに集める。ウェブ版で散らばっていた分。
@MainActor
final class WalkStore {
    enum Stage { case planning, picking, walking, arrived }
    enum Mode { case wander, crossTown }

    var stage: Stage = .planning
    var mode: Mode = .wander
    var kinds: Set<Kind> = [.food, .culture, .green]
    var picks: [Spot] = []
    var destination: Spot?
    var origin: Coordinate?
    var here: Coordinate?
    var heading: Double?
    var course: Route.Course?
    var stops: [Spot] = []
    var note: String?
    var startedAt: Date?
    var hintsUsed = 0
    /// 出発地よりどれだけ空いた場所へ出たか。人流誘導の成果そのもの。
    var dispersion = 0
    /// いま何時として扱うか。デモではここを差し替える。
    var clock: () -> Date = { Date() }
    /// 表示の言語。英語が主。カバーで切り替える。
    var lang: Lang = .en

    let draw = Draw()
    let route = Route()
    let crowd = Crowd()
    let data = SozoroData.shared

    var onChange: (() -> Void)?
    private func changed() { onChange?() }

    /// 地図に出す基準地点。ウェブ版のヒートマップにあたる。
    lazy var landmarks: [Spot] = Array(data.spots.prefix(70))
    func crowdLevel(_ s: Spot) -> Int { crowd.level(s, at: clock()) }

    var remaining: Double? {
        guard let h = here, let d = destination else { return nil }
        return Geo.distance(h, d.coordinate)
    }
    var arrived: Bool { (remaining ?? .infinity) <= draw.config.arrivalMetres }
    var minutesLeft: Int { draw.config.minutes(forStraight: remaining ?? 0) }

    /// ここから歩き回れるか。さがすものの絞り込みとは切り離す。
    /// 混ぜると、夜に飲食が外れただけで歩き方まで塞がってしまう。
    var wanderCount: Int? {
        guard let h = here else { return nil }
        let t = draw.target, tol = draw.tolerance
        return data.spots.filter {
            let d = Geo.distance(h, $0.coordinate)
            return abs(d - t) <= tol && d >= draw.config.minMetres
                && kinds.contains($0.kind) && $0.kind.isOpen(at: clock())
        }.count
    }

    func toggle(_ k: Kind) {
        if kinds.contains(k), kinds.count > 1 { kinds.remove(k) } else { kinds.insert(k) }
        changed()
    }
    func set(mode m: Mode) { mode = m; changed() }

    /// 台東区の中にいるか。外なら行き先が薄くなるので、そう伝える。
    var insideWard: Bool { here.map { Ward.taito.contains($0) } ?? true }

    func begin() {
        guard let h = here else { return }
        origin = h
        switch mode {
        case .wander: dealThree(from: h)
        case .crossTown: startCourse(from: h)
        }
    }

    func dealThree(from h: Coordinate) {
        var ctx = Draw.Context(origin: h, kinds: kinds, now: clock())
        stops.forEach { ctx.visited.insert($0.id) }
        var rng = SystemRandomNumberGenerator()
        let r = draw.pickMany(draw.candidates(ctx), ctx, using: &rng)
        guard !r.picks.isEmpty else {
            note = "Nothing in range from here. Try the other kind of place."
            changed(); return
        }
        picks = r.picks
        note = r.widenedMinutes > 0
            ? "Not much within 15 minutes — widened to ±\(r.widenedMinutes) min." : nil
        stage = .picking; changed()
    }

    func choose(_ s: Spot) {
        destination = s; origin = here; startedAt = Date(); hintsUsed = 0; stage = .walking; changed()
    }

    func startCourse(from h: Coordinate) {
        let opts = route.options(from: h)
        guard let pick = opts.randomElement() else {
            note = "No station within walking range from here."; changed(); return
        }
        let c = route.build(from: h, to: pick)
        course = c; destination = c.stops.first; origin = h; startedAt = Date(); hintsUsed = 0
        stage = .walking; changed()
    }

    func arrive() {
        if let d = destination { stops.append(d) }
        stage = .arrived; changed()
    }

    func next() {
        if var c = course, c.remaining > 0 {
            c.index += 1; course = c
            destination = c.stops[c.index]; origin = here; startedAt = Date(); hintsUsed = 0
            stage = .walking; changed(); return
        }
        course = nil
        if let h = here { dealThree(from: h) } else { stage = .planning; changed() }
    }

    func reset() {
        stage = .planning; picks = []; destination = nil
        course = nil; stops = []; note = nil; changed()
    }

    func name(_ s: Spot) -> String { data.displayName(s, japanese: lang == .ja) }
    func category(_ s: Spot) -> String { Copy.category(s.category, lang) }

    /// 三択のあいだで文が重ならないようにする。
    func teasers(for picks: [Spot]) -> [String] {
        var used = Set<String>(), out: [String] = []
        for p in picks {
            let t = Copy.teaser(p, lang, avoid: used)
            used.insert(t); out.append(t)
        }
        return out
    }
    func teaser(_ s: Spot) -> String { Copy.teaser(s, lang) }

    func meta(_ s: Spot) -> String {
        guard let h = here else { return "" }
        let d = Geo.distance(h, s.coordinate)
        let m = draw.config.minutes(forStraight: d)
        let f = DateFormatter(); f.dateFormat = "H:mm"
        let back = f.string(from: Date().addingTimeInterval(Double(m * 2 + 10) * 60))
        return lang == .ja ? "\(format(d))・徒歩\(m)分・\(back)には戻れます"
                           : "\(format(d)) · \(m) min walk · back by \(back)"
    }

    func format(_ m: Double) -> String {
        m >= 2000 ? String(format: "%.1f km", m / 1000)
                  : "\(Int((m / 10).rounded()) * 10) m"
    }

    /// 英語のときだけ、読みが分かっていれば頭文字を英語で返す。
    func firstLetter(_ s: Spot) -> String {
        Copy.firstLetter(s, lang, english: data.namesEN[s.name])
    }
}

/// プレビューでも中身が入っているように、上野に立たせた状態を作る。
@MainActor
extension WalkStore {
    static func preview(stage: Stage = .planning, lang: Lang = .en) -> WalkStore {
        let s = WalkStore()
        s.lang = lang
        s.here = Coordinate(lat: 35.7138, lon: 139.7772)
        s.origin = s.here
        switch stage {
        case .planning: break
        case .picking:
            var ctx = Draw.Context(origin: s.here!, kinds: s.kinds, now: Date())
            var rng = SystemRandomNumberGenerator()
            s.picks = s.draw.pickMany(s.draw.candidates(ctx), ctx, using: &rng).picks
            _ = ctx
            s.stage = .picking
        case .walking, .arrived:
            var ctx = Draw.Context(origin: s.here!, kinds: s.kinds, now: Date())
            var rng = SystemRandomNumberGenerator()
            s.destination = s.draw.pick(s.draw.candidates(ctx), ctx, using: &rng)
            _ = ctx
            s.heading = 42
            if stage == .arrived, let d = s.destination { s.stops = [d] }
            s.stage = stage
        }
        return s
    }
}
