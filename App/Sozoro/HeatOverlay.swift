import UIKit
import MapKit
import SozoroCore

/// 混雑のにじみ。ウェブ版の <g id="heat"> と同じで、
/// 基準地点に色の丸をぼかして重ね、掛け算で合成する。
/// 点だけだと「どのあたりが混んでいるか」が読めないので、面で出す。
/// 混雑のにじみ。ウェブ版の refreshHeat をそのまま移したもの。
///
///   r  = 22 + crowd * 0.36            （16m/px の画面での px）
///   色 = 空き=緑 / ふつう=琥珀 / 混雑=朱
///   濃さ = 0.10 + crowd/100 * 0.34
///
/// 比で正規化したり時刻で減衰させたりはしない。絶対値をそのまま出す。
/// 深夜に薄くなるのは「実際に空いている」からで、それが正しい。
final class HeatOverlay: NSObject, MKOverlay {
    let blobs: [(coordinate: CLLocationCoordinate2D, crowd: Int)]
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    /// ウェブ版の図は 16m/px。半径の px をメートルに戻すための係数。
    static let metresPerPixel = 16.0

    init(landmarks: [Landmark], crowd: Crowd, now: Date) {
        blobs = landmarks.map {
            (CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon),
             crowd.level($0.asSpot, at: now))
        }
        coordinate = CLLocationCoordinate2D(latitude: 35.7180, longitude: 139.7880)
        let c = MKMapPoint(coordinate)
        let span = 12000.0 * MKMapPointsPerMeterAtLatitude(35.718)
        boundingMapRect = MKMapRect(x: c.x - span / 2, y: c.y - span / 2,
                                    width: span, height: span)
        super.init()
    }
}

final class HeatRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let heat = overlay as? HeatOverlay else { return }
        // ウェブ版は mix-blend-mode: multiply と feGaussianBlur。
        // ここでは掛け算合成と、中心から外へ抜ける階調で同じ見え方にする。
        ctx.setBlendMode(.multiply)
        for b in heat.blobs {
            let p = point(for: MKMapPoint(b.coordinate))
            let px = 22 + Double(b.crowd) * 0.36
            let radius = CGFloat(px * HeatOverlay.metresPerPixel
                                 * MKMapPointsPerMeterAtLatitude(35.718))
            let alpha = CGFloat(0.10 + Double(b.crowd) / 100 * 0.34)
            let c = Theme.crowdColour(b.crowd)
            let colours = [c.withAlphaComponent(alpha).cgColor,
                           c.withAlphaComponent(0).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colours, locations: [0, 1]) else { continue }
            ctx.saveGState()
            ctx.drawRadialGradient(g, startCenter: p, startRadius: 0,
                                   endCenter: p, endRadius: radius,
                                   options: .drawsAfterEndLocation)
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
