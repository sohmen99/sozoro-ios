import Foundation

/// 焼き込んだ候補地。通信は一度もしない。
public struct SozoroData: Sendable {
    public let spots: [Spot]
    public let culture: [Spot]
    public let stations: [Spot]
    public let mesh: [MeshCell]
    public let namesEN: [String: String]
    public let stationNamesEN: [String: String]
    /// 行き先の名前 → 実写真。170件中58件にある。
    public let photos: [String: Photo]

    public static let shared: SozoroData = load()

    struct RawSpot: Codable { let name: String; let lat: Double; let lon: Double
                              var kind: String?; var category: String? }
    struct RawNames: Codable { let spots: [String: String]; let stations: [String: String] }

    static func decode<T: Decodable>(_ file: String, as: T.Type) -> T {
        guard let url = Bundle.module.url(forResource: file, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let v = try? JSONDecoder().decode(T.self, from: data)
        else { fatalError("同梱データを読めない: \(file).json") }
        return v
    }

    static func load() -> SozoroData {
        let s: [RawSpot] = decode("spots", as: [RawSpot].self)
        let c: [RawSpot] = decode("culture", as: [RawSpot].self)
        let st: [RawSpot] = decode("stations", as: [RawSpot].self)
        let m: [MeshCell] = decode("mesh", as: [MeshCell].self)
        let n: RawNames = decode("names", as: RawNames.self)
        let ph: [String: Photo] = decode("photos", as: [String: Photo].self)
        return SozoroData(
            spots: s.enumerated().map { i, r in
                Spot(id: "s/\(i)", name: r.name, coordinate: .init(lat: r.lat, lon: r.lon),
                     kind: Kind(rawValue: r.kind ?? "culture") ?? .culture,
                     category: r.category ?? "")
            },
            culture: c.enumerated().map { i, r in
                Spot(id: "c/\(i)", name: r.name, coordinate: .init(lat: r.lat, lon: r.lon),
                     kind: .culture, category: r.category ?? "文化財")
            },
            stations: st.map { r in
                Spot(id: "st/\(r.name)", name: r.name, coordinate: .init(lat: r.lat, lon: r.lon),
                     kind: .culture, category: "駅", isStation: true)
            },
            mesh: m, namesEN: n.spots, stationNamesEN: n.stations, photos: ph)
    }

    /// 英語で見ている人に、読める名前を返す。分かっている分だけ添える。
    public func displayName(_ spot: Spot, japanese: Bool) -> String {
        if japanese { return spot.name }
        let en = spot.isStation ? stationNamesEN[spot.name] : namesEN[spot.name]
        guard let en, !en.isEmpty else { return spot.name }
        return spot.isStation ? "\(en) Station" : "\(en) – \(spot.name)"
    }
}
