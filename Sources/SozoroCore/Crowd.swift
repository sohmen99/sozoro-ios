import Foundation

/// 国土交通省 全国の人流オープンデータ（1kmメッシュ・2019年10月）の1セル。
public struct MeshCell: Codable, Sendable {
    public let lat: Double, lon: Double
    public let weekend: Double, weekday: Double
}

/// 混雑の見立て。3つの層でできていて、実測はいちばん下だけ。
public struct Crowd: Sendable {
    let mesh: [MeshCell]
    let meshLo: Double, meshHi: Double

    /// 種類ごとの一日のかたち（0〜1）。0時から23時。
    static let curves: [Kind: [Double]] = [
        .culture: [0.02,0.01,0.01,0.01,0.02,0.05,0.12,0.22,0.38,0.62,0.84,0.96,
                   1.00,0.98,0.92,0.82,0.66,0.48,0.32,0.22,0.16,0.10,0.06,0.03],
        .food:    [0.06,0.03,0.02,0.02,0.02,0.04,0.10,0.20,0.32,0.44,0.58,0.86,
                   1.00,0.88,0.66,0.58,0.60,0.72,0.92,0.98,0.88,0.64,0.38,0.18]
    ]

    public init(mesh: [MeshCell] = SozoroData.shared.mesh) {
        self.mesh = mesh
        // 実データの5%〜95%点で 0〜1 に正規化する。都心はどこも人が多く、生値では差が出ない。
        let v = mesh.map { max($0.weekend, $0.weekday) }.sorted()
        self.meshLo = v[Int(Double(v.count) * 0.05)]
        self.meshHi = v[Int(Double(v.count) * 0.95)]
    }

    /// 層1・地域の人出（実測）。周囲2.4kmを距離の逆二乗で内挿する。
    public func footfall(at p: Coordinate, weekend: Bool) -> Double {
        var num = 0.0, den = 0.0
        for m in mesh {
            let d = max(150, Geo.distance(p, Coordinate(lat: m.lat, lon: m.lon)))
            if d > 2400 { continue }
            let w = 1 / (d * d)
            num += w * (weekend ? m.weekend : m.weekday)
            den += w
        }
        guard den > 0 else { return 0.5 }
        return min(1, max(0, (num / den - meshLo) / (meshHi - meshLo)))
    }

    /// 0〜100 の混み具合。層3（時間）× 層2（集客力）を土台に、層1で100側へ引き寄せる。
    public func level(_ spot: Spot, at when: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute, .weekday], from: when)
        let h = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        let curve = Self.curves[spot.kind] ?? Self.curves[.culture]!
        let i = Int(h) % 24, j = (i + 1) % 24, t = h - h.rounded(.down)
        let shape = curve[i] * (1 - t) + curve[j] * t
        let isWeekend = (c.weekday == 1 || c.weekday == 7)
        let pull = pow(footfall(at: spot.coordinate, weekend: isWeekend), 1.9)
        let base = min(100, shape * spot.kind.pop * (isWeekend ? 1.15 : 1) * 100)
        return Int(min(100, max(0, (base + (100 - base) * pull * 0.50).rounded())))
    }
}
