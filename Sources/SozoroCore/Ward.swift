import Foundation

/// 台東区の輪郭。区の外へ出たら、そう言う。
/// 地図は実測図なので位置はずれないが、行き先の母集団が台東区と荒川区に偏っているため、
/// 遠くから開いた人には「ここは範囲の外です」と伝えたほうが親切になる。
public struct Ward: Sendable {
    public let rings: [[Coordinate]]
    public static let taito = Ward()

    public init() {
        guard let url = Bundle.module.url(forResource: "ward", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([[[Double]]].self, from: data)
        else { rings = []; return }
        rings = raw.map { $0.map { Coordinate(lat: $0[0], lon: $0[1]) } }
    }

    /// 交差数で内外を決める。多重リングにも効く。
    public func contains(_ p: Coordinate) -> Bool {
        var inside = false
        for r in rings where r.count > 2 {
            var j = r.count - 1
            for i in r.indices {
                let a = r[i], b = r[j]
                if (a.lat > p.lat) != (b.lat > p.lat),
                   p.lon < (b.lon - a.lon) * (p.lat - a.lat) / (b.lat - a.lat) + a.lon {
                    inside.toggle()
                }
                j = i
            }
        }
        return inside
    }

    /// 区の外にいるとき、いちばん近い基準地点との関係で位置を伝える。
    public func nearest(to p: Coordinate, among spots: [Spot]) -> (spot: Spot, metres: Double, bearing: Double)? {
        guard let best = spots.min(by: {
            Geo.distance(p, $0.coordinate) < Geo.distance(p, $1.coordinate)
        }) else { return nil }
        return (best, Geo.distance(p, best.coordinate), Geo.bearing(p, best.coordinate))
    }
}
