import UIKit
import MapKit
import SozoroCore

/// 混雑のにじみ。ウェブ版の <g id="heat"> と同じで、
/// 基準地点に色の丸をぼかして重ね、掛け算で合成する。
/// 点だけだと「どのあたりが混んでいるか」が読めないので、面で出す。
final class HeatOverlay: NSObject, MKOverlay {
    let blobs: [(coordinate: CLLocationCoordinate2D, crowd: Int, pop: Double, share: Double)]
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(landmarks: [Landmark], crowd: Crowd, now: Date) {
        let values = landmarks.map { crowd.level($0.asSpot, at: now) }
        // 絶対値で切ると、深夜は全地点が45を割って層ごと消える（0〜6時と23時）。
        // その時刻のいちばん混んでいる所を基準にして、比で描く。
        // いつ見ても「どこが相対的に混んでいるか」は出る。
        let peak = Double(max(values.max() ?? 1, 1))
        blobs = zip(landmarks, values).map {
            (CLLocationCoordinate2D(latitude: $0.0.lat, longitude: $0.0.lon),
             $0.1, $0.0.pop, Double($0.1) / peak)
        }
        coordinate = CLLocationCoordinate2D(latitude: 35.7180, longitude: 139.7880)
        let c = MKMapPoint(coordinate)
        let span = 9000.0 * MKMapPointsPerMeterAtLatitude(35.718)
        boundingMapRect = MKMapRect(x: c.x - span / 2, y: c.y - span / 2,
                                    width: span, height: span)
        super.init()
    }
}

final class HeatRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let heat = overlay as? HeatOverlay else { return }
        // 下の2割は描かない。全部にじませると地図が色に沈んで、濃い所が読めなくなる。
        ctx.setBlendMode(.multiply)
        for b in heat.blobs where b.share > 0.45 {
            let p = point(for: MKMapPoint(b.coordinate))
            // 集客力が大きいほど広くにじむ。混んでいるほど濃い。
            // 集客力が大きいほど広くにじむ。地図の縮尺に合わせて実距離で持つ。
            let radius = CGFloat((420 + 900 * b.pop) * MKMapPointsPerMeterAtLatitude(35.718))
            // 色はその地点の絶対値で決める（空き=緑・ふつう=琥珀・混雑=朱）。
            // 濃さはその時刻の最大との比で決める。だから深夜でも濃淡は出る。
            let c = Theme.crowdColour(b.crowd)
            let t = (b.share - 0.45) / 0.55                       // 0〜1
            let alpha = 0.10 + 0.42 * CGFloat(min(1, max(0, t)))
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
