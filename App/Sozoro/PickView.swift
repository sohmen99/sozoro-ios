import SwiftUI
import SozoroCore

/// 状態をひとつに集める。ウェブ版で散らばっていたものをここに寄せた。
@MainActor
final class WalkModel: ObservableObject {
    enum Stage { case planning, picking, walking, arrived }
    enum Mode { case wander, crossTown }

    @Published var stage: Stage = .planning
    @Published var mode: Mode = .wander
    @Published var kinds: Set<Kind> = [.food, .culture]
    @Published var picks: [Spot] = []
    @Published var destination: Spot?
    @Published var here: Coordinate?
    @Published var heading: Double?
    @Published var note: String?
    @Published var course: Route.Course?
    @Published var stops: [Spot] = []
    @Published var origin: Coordinate?

    let draw = Draw()
    let route = Route()
    let crowd = Crowd()
    let data = SozoroData.shared

    /// 地図に出す基準地点と、その混み具合。
    var visibleSpots: [(Spot, Int)] {
        let now = Date()
        return data.spots.prefix(60).map { ($0, crowd.level($0, at: now)) }
    }

    func toggle(_ k: Kind) {
        if kinds.contains(k), kinds.count > 1 { kinds.remove(k) } else { kinds.insert(k) }
    }

    var remainingMetres: Double? {
        guard let h = here, let d = destination else { return nil }
        return Geo.distance(h, d.coordinate)
    }

    func begin() {
        guard let h = here else { return }
        origin = h
        switch mode {
        case .wander:    dealThree(from: h)
        case .crossTown: startCourse(from: h)
        }
    }

    func dealThree(from h: Coordinate) {
        var ctx = Draw.Context(origin: h, kinds: kinds, now: Date())
        for s in stops { ctx.visited.insert(s.id) }
        let pool = draw.candidates(ctx)
        var rng = SystemRandomNumberGenerator()
        let r = draw.pickMany(pool, ctx, using: &rng)
        guard !r.picks.isEmpty else {
            note = "Nothing in range from here. Try the other kind of place."
            return
        }
        picks = r.picks
        note = r.widenedMinutes > 0
            ? "Not much within 15 minutes — widened to ±\(r.widenedMinutes) min."
            : nil
        stage = .picking
    }

    func choose(_ s: Spot) {
        destination = s
        origin = here
        stage = .walking
    }

    func startCourse(from h: Coordinate) {
        let opts = route.options(from: h)
        guard let pick = opts.randomElement() else {
            note = "No station within walking range from here."
            return
        }
        let c = route.build(from: h, to: pick)
        course = c
        destination = c.stops.first
        stage = .walking
    }

    func arrive() {
        if let d = destination { stops.append(d) }
        stage = .arrived
    }

    func next() {
        guard var c = course, c.remaining > 0 else {
            if let h = here { dealThree(from: h) } else { stage = .planning }
            return
        }
        c.index += 1
        course = c
        destination = c.stops[c.index]
        origin = here
        stage = .walking
    }

    func reset() {
        stage = .planning; picks = []; destination = nil; course = nil; stops = []; note = nil
    }
}

/// 三択。正体は伏せたまま、距離と一行だけ見せる。
struct PickView: View {
    @ObservedObject var model: WalkModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("THREE WAYS FROM HERE").font(.caption2.weight(.semibold))
                    .tracking(1.4).foregroundStyle(.tertiary)
                Text("Pick one. We still will not say.")
                    .font(.title3.weight(.semibold))
            }

            ForEach(model.picks) { s in
                Button { model.choose(s) } label: {
                    HStack(spacing: 13) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint(s).gradient)
                            .frame(width: 74, height: 74)
                            .blur(radius: 5).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(Image(systemName: s.kind == .food ? "fork.knife" : "building.columns")
                                        .foregroundStyle(.white.opacity(0.55)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(teaser(s)).font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                            Text(meta(s)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(11)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let n = model.note {
                Text(n).font(.caption).foregroundStyle(.secondary)
            }
            Button("Back") { model.reset() }
                .font(.footnote).frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(10)
    }

    /// 正体を伏せた一行。同じ場所には毎回同じ文が当たるよう、名前から選ぶ。
    func teaser(_ s: Spot) -> String {
        let food = ["A small sign. The locals know it",
                    "One street back from the crowd",
                    "A light on in a narrow lane"]
        let cult = ["A quiet precinct the guidebooks skip",
                    "Something old, still standing here",
                    "A gate, and no one behind it"]
        let set = s.kind == .food ? food : cult
        return set[abs(s.name.hashValue) % set.count]
    }

    func meta(_ s: Spot) -> String {
        guard let h = model.here else { return "" }
        let d = Geo.distance(h, s.coordinate)
        let m = model.draw.config.minutes(forStraight: d)
        let back = Date().addingTimeInterval(Double(m * 2 + 10) * 60)
        let f = DateFormatter(); f.dateFormat = "H:mm"
        return "\(fmt(d)) · \(m) min walk · back by \(f.string(from: back))"
    }

    func fmt(_ m: Double) -> String {
        m >= 2000 ? String(format: "%.1f km", m / 1000) : "\(Int((m / 10).rounded()) * 10) m"
    }

    func tint(_ s: Spot) -> Color {
        s.kind == .food ? Color(red: 0.55, green: 0.35, blue: 0.20)
                        : Color(red: 0.24, green: 0.32, blue: 0.42)
    }
}
