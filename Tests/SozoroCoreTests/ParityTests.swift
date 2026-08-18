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
        let weightNight: [Weight]
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
                               kinds: [.food, .culture, .green], now: Self.when)
        let spots = SozoroData.shared.spots
        for g in Self.golden.weight {
            guard let s = spots.first(where: { $0.name == g.name }) else {
                return XCTFail("地点が無い: \(g.name)")
            }
            XCTAssertEqual(d.weight(s, ctx), g.value, accuracy: 1e-9, "重み \(g.name)")
        }
    }

    /// 深夜。飲食が閉まり、寺社と公園だけが残る。ウェブ版の isOpen と同じになるか。
    func testWeightAtNight() {
        let d = Draw()
        var c = DateComponents(); c.year = 2026; c.month = 8; c.day = 18; c.hour = 2
        let night = Calendar.current.date(from: c)!
        let ctx = Draw.Context(origin: .init(lat: 35.7138, lon: 139.7772),
                               kinds: [.food, .culture, .green], now: night)
        let spots = SozoroData.shared.spots
        for g in Self.golden.weightNight {
            guard let s = spots.first(where: { $0.name == g.name }) else {
                return XCTFail("地点が無い: \(g.name)")
            }
            XCTAssertEqual(d.weight(s, ctx), g.value, accuracy: 1e-9, "深夜の重み \(g.name)")
        }
    }

    /// 焼き込んだ写真。索けること、束の中に実体があること、撮影者が空でないこと。
    func testPhotosAreBundled() {
        let d = SozoroData.shared
        XCTAssertEqual(d.photos.count, 58, "写真の件数")
        var missing: [String] = []
        for s in d.spots where d.photo(for: s) != nil {
            if d.photoURL(for: s) == nil { missing.append(s.name) }
            XCTAssertFalse(d.photo(for: s)!.artist.isEmpty, "撮影者が空: \(s.name)")
            XCTAssertFalse(d.photo(for: s)!.licence.isEmpty, "ライセンスが空: \(s.name)")
        }
        XCTAssertTrue(missing.isEmpty, "束に実体が無い: \(missing)")
        // 落としたものが戻っていないか。同名の別の寺と、照合ちがいの2件。
        for bad in ["本行寺", "筆や", "長久院"] {
            XCTAssertNil(d.photos[bad], "外したはずの写真が戻っている: \(bad)")
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

extension ParityTests {
    /// 区の内外。ウェブ版の insideWard と同じ結果になること。
    func testWardContains() {
        let w = Ward.taito
        XCTAssertFalse(w.rings.isEmpty, "区の輪郭を読めていない")
        let cases: [(String, Double, Double, Bool)] = [
            ("上野公園", 35.71538, 139.7734, true), ("浅草寺", 35.7148, 139.7967, true),
            ("谷中", 35.7276, 139.7663, true), ("蔵前", 35.7039, 139.7897, true),
            ("根岸", 35.7255, 139.7860, true),
            ("南千住", 35.7331, 139.7986, false), ("東京駅", 35.6812, 139.7671, false),
            ("押上", 35.7101, 139.8134, false), ("日暮里", 35.7278, 139.7710, false)
        ]
        for (n, la, lo, want) in cases {
            XCTAssertEqual(w.contains(Coordinate(lat: la, lon: lo)), want, n)
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

/// 三択が同じ顔にならないか。ウェブ版で3文しか無かった問題の再発防止。
final class TeaserTests: XCTestCase {
    func testVariety() {
        let spots = SozoroData.shared.spots
        var seen = Set<String>()
        for s in spots { seen.insert(Copy.teaser(s, .en)) }
        XCTAssertGreaterThanOrEqual(seen.count, 30, "一行の種類が少なすぎる: \(seen.count)")
    }

    func testStableForSameSpot() {
        guard let s = SozoroData.shared.spots.first else { return XCTFail() }
        XCTAssertEqual(Copy.teaser(s, .en), Copy.teaser(s, .en), "同じ場所で文が変わる")
    }

    func testAvoidsRepeatsWithinADeal() {
        let d = Draw()
        var rng = SeededGenerator(seed: 11)
        let ctx = Draw.Context(origin: .init(lat: 35.7138, lon: 139.7772), now: Date())
        let pool = d.candidates(ctx)
        for _ in 0..<200 {
            let picks = d.pickMany(pool, ctx, using: &rng).picks
            var used = Set<String>()
            for p in picks { used.insert(Copy.teaser(p, .en, avoid: used)) }
            XCTAssertEqual(used.count, picks.count, "同じ回に同じ文が並んだ")
        }
    }

    func testCategoryIsEnglishInEnglish() {
        for s in SozoroData.shared.spots {
            let c = Copy.category(s.category, .en)
            XCTAssertFalse(c.contains("飲食"), "英語なのに日本語のまま: \(c)")
            XCTAssertFalse(c.contains("文化財のある"), "英語なのに日本語のまま: \(c)")
        }
    }
}
