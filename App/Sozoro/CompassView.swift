import SwiftUI
import SozoroCore

/// コンパス。針は片側だけ。追う先を取り違えないように、反対の端は短い重りにする。
struct CompassView: View {
    @ObservedObject var model: WalkModel
    @State private var shown: Double = 0     // 角度を足しこむ。北をまたいで逆回りしないように。

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("We are not telling you yet").font(.headline)
                Text(sub).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ZStack {
                Circle().stroke(.quaternary, lineWidth: 1).frame(width: 264, height: 264)
                Circle().stroke(.quaternary, lineWidth: 1).frame(width: 208, height: 208)
                ForEach(["N": 0.0, "E": 90.0, "S": 180.0, "W": 270.0].sorted(by: { $0.value < $1.value }), id: \.key) { m in
                    Text(m.key).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                        .offset(y: -142).rotationEffect(.degrees(m.value))
                }
                if let p = progress {
                    Circle().trim(from: 0, to: p)
                        .stroke(Color(red: 0.21, green: 0.72, blue: 0.60),
                                style: .init(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 264, height: 264)
                }
                needle
            }
            .frame(height: 290)

            HStack(spacing: 26) {
                metric(distanceText, "LEFT")
                metric("\(minutesLeft)", "ON FOOT")
                metric(String(format: "%03.0f°", bearing ?? 0), "BEARING")
            }

            Button {
                model.arrive()
            } label: {
                Text(arrived ? "You made it" : "I'm here")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent).tint(arrived ? .green : .primary)

            Button("Give up") { model.reset() }.font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(10)
        .onChange(of: rotation) { _, r in turn(to: r) }
        .onAppear { shown = rotation }
    }

    private var needle: some View {
        ZStack {
            // 重り。行き先とまちがえないよう短く暗く。
            Capsule().fill(.secondary.opacity(0.45)).frame(width: 3, height: 44)
                .offset(y: 22)
            // 追う先。
            Capsule().fill(Color(red: 0.21, green: 0.72, blue: 0.60))
                .frame(width: 5, height: 86).offset(y: -43)
            Triangle().fill(Color(red: 0.21, green: 0.72, blue: 0.60))
                .frame(width: 26, height: 30).offset(y: -100)
            Circle().stroke(Color(red: 0.21, green: 0.72, blue: 0.60), lineWidth: 2)
                .background(Circle().fill(Color(.systemBackground)))
                .frame(width: 9, height: 9).offset(y: -64)
            Text("THIS WAY").font(.system(size: 9, weight: .semibold).monospaced())
                .tracking(1.6).foregroundStyle(Color(red: 0.21, green: 0.72, blue: 0.60))
                .offset(y: -38)
                .rotationEffect(.degrees(-shown))     // 文字だけ立てておく
        }
        .rotationEffect(.degrees(shown))
        .animation(.easeOut(duration: 0.25), value: shown)
    }

    private func metric(_ v: String, _ k: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.title3.monospacedDigit().weight(.semibold))
            Text(k).font(.system(size: 9, weight: .semibold)).tracking(1.2)
                .foregroundStyle(.tertiary)
        }
    }

    /// 差を -180〜180 に畳んでから足す。359°から1°へ逆回りしない。
    private func turn(to r: Double) {
        let delta = ((r - shown).truncatingRemainder(dividingBy: 360) + 540)
                        .truncatingRemainder(dividingBy: 360) - 180
        shown += delta
    }

    private var bearing: Double? {
        guard let h = model.here, let d = model.destination else { return nil }
        return Geo.bearing(h, d.coordinate)
    }
    private var rotation: Double {
        guard let b = bearing else { return 0 }
        return model.heading == nil ? b : b - model.heading!
    }
    private var remaining: Double? { model.remainingMetres }
    private var arrived: Bool { (remaining ?? .infinity) <= model.draw.config.arrivalMetres }
    private var minutesLeft: Int { model.draw.config.minutes(forStraight: remaining ?? 0) }
    private var progress: Double? {
        guard let o = model.origin, let d = model.destination, let r = remaining else { return nil }
        let total = Geo.distance(o, d.coordinate)
        guard total > 1 else { return nil }
        return min(1, max(0, 1 - r / total))
    }
    private var distanceText: String {
        guard let r = remaining else { return "—" }
        return r >= 2000 ? String(format: "%.1fkm", r / 1000) : "\(Int((r / 10).rounded()) * 10)m"
    }
    private var sub: String {
        guard let b = bearing else { return "Working out where to send you…" }
        let dir = Geo.compassEN[Geo.compassIndex(b)]
        return model.heading == nil
            ? "Follow the green tip. Something quiet, \(dir) of here. The dial is north-up."
            : "Follow the green tip. Something quiet, \(dir) of here."
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY * 0.72))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// 到着。ここで初めて正体を出す。
struct ArrivalView: View {
    @ObservedObject var model: WalkModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("YOU MADE IT").font(.caption2.weight(.semibold))
                    .tracking(1.4).foregroundStyle(.tertiary)
                Text("This is what it was.").font(.title2.weight(.semibold))
            }
            if let d = model.destination {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.data.displayName(d, japanese: false))
                        .font(.title3.weight(.semibold))
                    Text(d.category).font(.caption).foregroundStyle(.secondary)
                    Text("\(model.stops.count) \(model.stops.count == 1 ? "stop" : "stops") so far")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            Button {
                model.next()
            } label: {
                Text(keepTitle).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent).tint(.primary)

            Button("Stop here") { model.reset() }
                .font(.footnote).frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(10)
    }

    private var keepTitle: String {
        if let c = model.course, c.remaining > 0 { return "Next stop" }
        if model.course != nil { return "Walk again" }
        return "Keep going"
    }
}
