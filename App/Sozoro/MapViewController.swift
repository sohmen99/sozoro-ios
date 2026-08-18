import UIKit
import MapKit
import SozoroCore

/// 表に出ている画面。混雑の地図と、その下から引き出すシート。
/// 混雑を見てから歩き方を決める、という順番はウェブ版と同じ。
@MainActor
final class MapViewController: UIViewController {
    let store: WalkStore
    let demo: DemoMode
    var onBegin: (() -> Void)?
    var onCover: (() -> Void)?
    var onRewards: (() -> Void)?
    var onDemoToggle: ((Bool) -> Void)?

    private let map = MKMapView()
    private lazy var sheet = SheetView(store: store)
    private lazy var panel = DemoPanel(demo: demo, store: store)

    init(store: WalkStore, demo: DemoMode) {
        self.store = store; self.demo = demo
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.washi

        map.mapType = .mutedStandard
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = !demo.on
        map.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: store.here?.lat ?? 35.7138,
                                           longitude: store.here?.lon ?? 139.7772),
            span: MKCoordinateSpan(latitudeDelta: 0.032, longitudeDelta: 0.032))
        map.delegate = self
        view.addSubview(map)
        map.pin(to: view)
        // 基準地点はウェブ版と同じ21件。アイコンと混み具合の色で置く。
        map.addAnnotations(Landmark.all.map {
            LandmarkPin(landmark: $0, crowd: store.crowd.level($0.asSpot, at: store.clock()))
        })

        // 遊べる範囲のちょい外までで止める。世界地図まで引けると、迷子になる。
        let play = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.7180, longitude: 139.7880),
            latitudinalMeters: 9000, longitudinalMeters: 9000)
        map.setCameraBoundary(MKMapView.CameraBoundary(coordinateRegion: play), animated: false)
        map.setCameraZoomRange(MKMapView.CameraZoomRange(minCenterCoordinateDistance: 900,
                                                        maxCenterCoordinateDistance: 14000),
                               animated: false)
        if demo.on {
            // デモでは地図を叩いた場所に立つ。実測は起こさない。
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            map.addGestureRecognizer(tap)
        }
        addMeMarker()

        view.addSubview(offArea)
        offArea.translatesAutoresizingMaskIntoConstraints = false
        offArea.isHidden = true

        sheet.onBegin = { [weak self] in self?.onBegin?() }
        sheet.onSlide = { [weak self] _ in self?.layoutOffArea() }
        view.addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 22)
        ])

        let bar = stack(.horizontal, 8, [
            roundButton("chevron.left") { [weak self] in self?.onCover?() },
            UIView(),
            roundButton("seal") { [weak self] in self?.onRewards?() },
            roundButton(demo.on ? "wand.and.stars.inverse" : "wand.and.stars") { [weak self] in
                guard let self else { return }
                self.onDemoToggle?(!self.demo.on)
            }
        ], align: .center)
        view.addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])

        if demo.on {
            panel.onChange = { [weak self] in self?.locationMoved() }
            view.addSubview(panel)
            panel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
                panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
                panel.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 10)
            ])
        }
        sheet.refresh()
        layoutOffArea()
        refreshOffArea()
    }

    private var detail: LandmarkDetailView?
    private var meMarker: MKPointAnnotation?
    private func addMeMarker() {
        guard demo.on, let h = store.here else { return }
        let a = MKPointAnnotation()
        a.coordinate = CLLocationCoordinate2D(latitude: h.lat, longitude: h.lon)
        map.addAnnotation(a)
        meMarker = a
    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        let p = g.location(in: map)
        let c = map.convert(p, toCoordinateFrom: map)
        store.here = Coordinate(lat: c.latitude, lon: c.longitude)
        meMarker.map { map.removeAnnotation($0) }
        addMeMarker()
        sheet.refresh()
    }

    func locationMoved() {
        sheet.refresh()
        refreshOffArea()
        if demo.on { meMarker.map { map.removeAnnotation($0) }; addMeMarker() }
    }

    /// 区の外にいるとき。行き先の母集団が台東区と荒川区に寄っているので、
    /// 遠くから開いた人には、いちばん近い基準地点との関係で位置を伝える。
    private let offArea = OffAreaBanner()

    private func layoutOffArea() {
        NSLayoutConstraint.deactivate(offAreaConstraints)
        offAreaConstraints = [
            offArea.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            offArea.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            offArea.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -10)
        ]
        NSLayoutConstraint.activate(offAreaConstraints)
    }
    private var offAreaConstraints: [NSLayoutConstraint] = []

    func refreshOffArea() {
        guard let h = store.here else { offArea.isHidden = true; return }
        if Ward.taito.contains(h) { offArea.isHidden = true; return }
        guard let n = Ward.taito.nearest(to: h, among: store.landmarks) else {
            offArea.isHidden = true; return
        }
        let km = n.metres >= 1000 ? String(format: "%.1f km", n.metres / 1000)
                                  : "\(Int((n.metres / 10).rounded()) * 10) m"
        let dir = Geo.compassEN[Geo.compassIndex(n.bearing)]
        offArea.set(title: "You are outside Taito",
                    body: "\(store.name(n.spot)) is \(km) to the \(dir). "
                        + "Places to walk to thin out this far from the ward.")
        offArea.isHidden = false
        layoutOffArea()
    }

    private func roundButton(_ symbol: String, _ act: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        var c = UIButton.Configuration.filled()
        c.image = UIImage(systemName: symbol)
        c.baseBackgroundColor = Theme.washi.withAlphaComponent(0.92)
        c.baseForegroundColor = Theme.ink
        c.cornerStyle = .capsule
        c.contentInsets = .init(top: 10, leading: 12, bottom: 10, trailing: 12)
        b.configuration = c
        b.addAction(UIAction { _ in act() }, for: .touchUpInside)
        return b
    }
}

/// 区の外にいることを伝える帯。地図の上、シートのすぐ上に出す。
final class OffAreaBanner: UIView {
    private let titleLabel = makeLabel("", Theme.body(13, .semibold), .white)
    private let bodyLabel = makeLabel("", Theme.body(11.5), UIColor.white.withAlphaComponent(0.8), lines: 0)

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.busy.withAlphaComponent(0.94)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        icon.tintColor = .white
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let col = stack(.vertical, 3, [titleLabel, bodyLabel])
        let row = stack(.horizontal, 11, [icon, col], align: .top)
        addSubview(row)
        row.pin(to: self, insets: .init(top: 12, left: 13, bottom: 12, right: 13))
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(title: String, body: String) {
        titleLabel.text = title; bodyLabel.text = body
    }
}

final class LandmarkPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let landmark: Landmark
    let crowd: Int
    init(landmark: Landmark, crowd: Int) {
        coordinate = CLLocationCoordinate2D(latitude: landmark.lat, longitude: landmark.lon)
        title = nil            // 吹き出しは使わない。自前の詳細を出す。
        self.landmark = landmark; self.crowd = crowd
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ m: MKMapView, viewFor a: MKAnnotation) -> MKAnnotationView? {
        if let p = a as? LandmarkPin {
            let id = "landmark"
            let v = m.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: a, reuseIdentifier: id)
            v.annotation = a
            v.canShowCallout = false
            v.subviews.forEach { $0.removeFromSuperview() }
            v.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
            v.backgroundColor = Theme.washi
            v.layer.cornerRadius = 17
            v.layer.borderWidth = 2
            v.layer.borderColor = Theme.crowdColour(p.crowd).cgColor
            v.layer.shadowColor = UIColor.black.cgColor
            v.layer.shadowOpacity = 0.18
            v.layer.shadowRadius = 3
            v.layer.shadowOffset = CGSize(width: 0, height: 1)
            let icon = IconView(p.landmark.icon, size: 18, colour: Theme.ink)
            icon.center = CGPoint(x: 17, y: 17)
            icon.translatesAutoresizingMaskIntoConstraints = true
            v.addSubview(icon)
            return v
        }
        return nil
    }

    /// 叩いたら詳細を出す。行き先ではなく、混雑の説明。
    func mapView(_ m: MKMapView, didSelect v: MKAnnotationView) {
        guard let p = v.annotation as? LandmarkPin else { return }
        m.deselectAnnotation(v.annotation, animated: false)
        showDetail(p.landmark)
    }

    func showDetail(_ l: Landmark) {
        detail?.removeFromSuperview()
        let d = LandmarkDetailView(landmark: l, crowd: store.crowd, now: store.clock())
        d.onClose = { [weak self] in
            UIView.animate(withDuration: 0.2) { self?.detail?.alpha = 0 } completion: { _ in
                self?.detail?.removeFromSuperview(); self?.detail = nil
            }
        }
        view.addSubview(d)
        d.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            d.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            d.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            d.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -10)
        ])
        d.alpha = 0
        d.transform = CGAffineTransform(translationX: 0, y: 14)
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
            d.alpha = 1; d.transform = .identity
        }
        detail = d
    }
}

