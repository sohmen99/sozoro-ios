import UIKit
import MapKit
import SozoroCore

/// 混雑のにじみ。ウェブ版の refreshHeat と <g id="heat"> をそのまま移したもの。
///
///   r    = 22 + crowd * 0.36          px（ベースマップは 16m/px）
///   色   = 空き=緑 / やや混=赤 / 混雑=紫
///   濃さ = 0.10 + crowd/100 * 0.34
///   ぼかし = feGaussianBlur stdDeviation="26"
///   全体  = mix-blend-mode:multiply, opacity 0.85
///
/// 比で正規化したり時刻で減衰させたりはしない。絶対値をそのまま出す。
/// 深夜に薄くなるのは「実際に空いている」からで、それが正しい。
///
/// ぼかしが効くと、小さい丸ほど中心まで薄まる。22px の丸は中心でも 0.30 までしか
/// 立たず、58px の丸は 0.92 立つ。空いている場所が目立たなくなるのはこの効きで、
/// ぼかさずに描くと全部が同じ濃さの塊に見えてしまう。
final class HeatOverlay: NSObject, MKOverlay {
    let blobs: [(coordinate: CLLocationCoordinate2D, crowd: Int)]
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    /// ウェブ版の図は 16m/px。半径の px をメートルに戻すための係数。
    static let metresPerPixel = 16.0
    /// feGaussianBlur stdDeviation="26"（px）
    static let sigma = 26.0
    /// <g id="heat"> にかかっている opacity
    static let groupOpacity = 0.85

    init(landmarks: [Landmark], crowd: Crowd, now: Date) {
        blobs = landmarks.map {
            (CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon),
             crowd.level($0.asSpot, at: now))
        }
        coordinate = CLLocationCoordinate2D(latitude: 35.7180, longitude: 139.7880)
        let c = MKMapPoint(coordinate)
        // ぼかしは半径の外へ 3σ ぶん広がるので、その分を見込んでおく。
        let span = 20000.0 * MKMapPointsPerMeterAtLatitude(35.718)
        boundingMapRect = MKMapRect(x: c.x - span / 2, y: c.y - span / 2,
                                    width: span, height: span)
        super.init()
    }
}

/// ぼかした円板の断面。半径 R の一様な円板に σ のガウスをかけたときの、
/// 中心からの距離ごとの濃さ。閉じた式にならないので数値積分して覚えておく。
/// R は 22〜58px の整数までしか出てこないので、一度作れば以後は引くだけ。
enum HeatProfile {
    static let stops = 22
    private static var cache: [Int: [CGFloat]] = [:]
    private static let lock = NSLock()

    /// 0 から R+3σ までを stops 等分した濃さの列（0〜1）。
    static func table(radius R: Double, sigma s: Double) -> [CGFloat] {
        let key = Int(R.rounded())
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[key] { return hit }
        let R = Double(key), outer = R + 3 * s
        let N = 48, M = 64
        var out: [CGFloat] = []
        out.reserveCapacity(stops)
        for k in 0..<stops {
            let d = outer * Double(k) / Double(stops - 1)
            var sum = 0.0
            for i in 0..<N {
                let r = (Double(i) + 0.5) * R / Double(N)
                for j in 0..<M {
                    let th = (Double(j) + 0.5) * 2 * .pi / Double(M)
                    sum += exp(-(r * r + d * d - 2 * r * d * cos(th)) / (2 * s * s)) * r
                }
            }
            let v = sum * (R / Double(N)) * (2 * .pi / Double(M)) / (2 * .pi * s * s)
            out.append(CGFloat(min(1, max(0, v))))
        }
        cache[key] = out
        return out
    }
}

final class HeatRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let heat = overlay as? HeatOverlay else { return }
        // ウェブ版は mix-blend-mode: multiply。
        ctx.setBlendMode(.multiply)
        let mpp = MKMapPointsPerMeterAtLatitude(35.718) * HeatOverlay.metresPerPixel
        for b in heat.blobs {
            let p = point(for: MKMapPoint(b.coordinate))
            let px = 22 + Double(b.crowd) * 0.36
            let outer = CGFloat((px + 3 * HeatOverlay.sigma) * mpp)
            let alpha = (0.10 + Double(b.crowd) / 100 * 0.34) * HeatOverlay.groupOpacity
            let c = Theme.crowdColour(b.crowd)
            let table = HeatProfile.table(radius: px, sigma: HeatOverlay.sigma)
            let colours = table.map { c.withAlphaComponent($0 * CGFloat(alpha)).cgColor } as CFArray
            let locs = (0..<table.count).map { CGFloat($0) / CGFloat(table.count - 1) }
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colours, locations: locs) else { continue }
            ctx.saveGState()
            ctx.drawRadialGradient(g, startCenter: p, startRadius: 0,
                                   endCenter: p, endRadius: outer, options: [])
            ctx.restoreGState()
        }
    }
}

/// 現在地。デモの立ち位置とも、基準地点とも見分けがつくようにする。
final class MeAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let demo: Bool
    init(coordinate: CLLocationCoordinate2D, demo: Bool) {
        self.coordinate = coordinate; self.demo = demo
    }
}

final class MeView: MKAnnotationView {
    private let ring = UIView()
    private let dot = UIView()
    private let badge = makeLabel("", Theme.mono(9, .semibold), .white, align: .center)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        isUserInteractionEnabled = false
        ring.frame = bounds
        ring.layer.cornerRadius = 22
        addSubview(ring)
        dot.frame = CGRect(x: 15, y: 15, width: 14, height: 14)
        dot.layer.cornerRadius = 7
        dot.layer.borderWidth = 2.5
        dot.layer.borderColor = UIColor.white.cgColor
        dot.layer.shadowColor = UIColor.black.cgColor
        dot.layer.shadowOpacity = 0.3
        dot.layer.shadowRadius = 2
        addSubview(dot)
        badge.frame = CGRect(x: -16, y: 30, width: 76, height: 14)
        addSubview(badge)
        restyle()
    }
    required init?(coder: NSCoder) { fatalError() }
    override var annotation: MKAnnotation? { didSet { restyle() } }

    private func restyle() {
        let demo = (annotation as? MeAnnotation)?.demo ?? false
        // 実測は藍、デモは琥珀。ひと目で今どちらを見ているか分かるようにする。
        let c = demo ? Theme.mid : Theme.ai
        ring.backgroundColor = c.withAlphaComponent(0.16)
        dot.backgroundColor = c
        badge.text = demo ? "DEMO" : ""
        badge.textColor = c
        badge.isHidden = !demo
    }
}
