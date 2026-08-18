import XCTest
@testable import SozoroCore

/// ウェブ版が出した値と突き合わせる。移植でずれていたら、ここで落ちる。
final class ParityTests: XCTestCase {

    struct Golden: Decodable {
        struct Geo: Decodable { let a: [Double]; let b: [Double]; let distance: Double; let bearing: Double }
        struct Foot: Decodable { let at: [Double]; let weekend: Bool; let value: Double }
        struct Crowd: Decodable { let name: String; let value: Int }
        struct Weight: Decodable { let name: String; let value: Double }
        struct Band: Decodable { let target: Double; let tol: Double; let max: Double }
        struct RouteOpt: Decodable { let dir: String; let station: String; let mins: Int; let stops: [String] }
        struct Route: Decodable { let origin: [Double]; let options: [RouteOpt] }
        let meshLo: Double, meshHi: Double
        let geo: [Geo], footfall: [Foot], crowd: [Crowd], weight: [Weight]
        let band: Band, routes: [Route]
    }

    static let golden: Golden = {
        let url = Bundle.module.url(forResource: "golden", withExtension: "json")!
        return try! JSONDecoder().decode(Golden.self, from: Data(contentsOf: url))
    }()

    /// 2026-08-18 14:00 火曜。正解値を作ったときと同じ時刻。
    static let when: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 18; c.hour = 14; c.minute = 0
        return Calendar.current.date(from: c)!
    }()

    func testGeo() {
        for g in Self.golden.geo {
            let a = Coordinate(lat: g.a[0], lon: g.a[1]), b = Coordinate(lat: g.b[0], lon: g.b[1])
            XCTAssertEqual(Geo.distance(a, b), g.distance, accuracy: 0.5, "距離")
            XCTAssertEqual(Geo.bearing(a, b), g.bearing, accuracy: 0.001, "方位")
        }
    }

    func testMeshNormalisation() {
        let c = SozoroCore.Crowd()
        XCTAssertEqual(c.meshLo, Self.golden.meshLo, accuracy: 0.001)
        XCTAssertEqual(c.meshHi, Self.golden.meshHi, accuracy: 0.001)
    }

    func testFootfall() {
        let c = SozoroCore.Crowd()
        for f in Self.golden.footfall {
            let v = c.footfall(at: .init(lat: f.at[0], lon: f.at[1]), weekend: f.weekend)
            XCTAssertEqual(v, f.value, accuracy: 0.0001, "人出 \(f.at)")
        }
    }

    func testCrowdLevel() {
        let c = SozoroCore.Crowd()
        let spots = SozoroData.shared.spots
        for g in Self.golden.crowd {
            guard let s = spots.first(where: { $0.name == g.name }) else {
                return XCTFail("地点が無い: \(g.name)")
            }
            XCTAssertEqual(c.level(s, at: Self.when), g.value, "混雑 \(g.name)")
        }
    }

    func testBand() {
        let d = Draw()
        XCTAssertEqual(d.target, Self.golden.band.target, accuracy: 0.01)
        XCTAssertEqual(d.tolerance, Self.golden.band.tol, accuracy: 0.01)
        XCTAssertEqual(d.searchRadius, Self.golden.band.max, accuracy: 0.01)
    }

    func testWeight() {
        let d = Draw()
        let ctx = Draw.Context(origin: .init(lat: 35.7138, lon: 139.7772),
                               kinds: [.food, .culture], now: Self.when)
        let spots = SozoroData.shared.spots
        for g in Self.golden.weight {
            guard let s = spots.first(where: { $0.name == g.name }) else {
                return XCTFail("地点が無い: \(g.name)")
            }
            XCTAssertEqual(d.weight(s, ctx), g.value, accuracy: 1e-9, "重み \(g.name)")
        }
    }

    func testRouteOptions() {
        let r = Route()
        for g in Self.golden.routes {
            let opts = r.options(from: .init(lat: g.origin[0], lon: g.origin[1]))
            XCTAssertEqual(opts.map(\.direction.key), g.options.map(\.dir), "方角 \(g.origin)")
            XCTAssertEqual(opts.map(\.station.name), g.options.map(\.station), "駅 \(g.origin)")
            XCTAssertEqual(opts.map(\.minutes), g.options.map(\.mins), "分 \(g.origin)")
            for (o, e) in zip(opts, g.options) {
                let c = r.build(from: .init(lat: g.origin[0], lon: g.origin[1]), to: o)
                XCTAssertEqual(c.stops.map(\.name), e.stops, "道筋 \(e.station)")
            }
        }
    }

    func testDrawAlwaysDealsThree() {
        let d = Draw()
        var rng = SeededGenerator(seed: 7)
        for start in [Coordinate(lat: 35.7138, lon: 139.7772),
                      Coordinate(lat: 35.7108, lon: 139.7967),
                      Coordinate(lat: 35.7276, lon: 139.7663)] {
            let ctx = Draw.Context(origin: start, now: Self.when)
            let pool = d.candidates(ctx)
            for _ in 0..<50 {
                let r = d.pickMany(pool, ctx, using: &rng)
                XCTAssertEqual(r.picks.count, 3, "3枚そろわない")
                XCTAssertEqual(Set(r.picks.map(\.id)).count, 3, "同じ地点が重なった")
                for p in r.picks {
                    let m = Double(Draw().config.minutes(forStraight: Geo.distance(start, p.coordinate)))
                    XCTAssertLessThanOrEqual(abs(m - 15), 8, "帯の外に出た \(p.name) \(m)分")
                }
            }
        }
    }
}

/// 種を決めた乱数。テストを毎回同じにする。
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
