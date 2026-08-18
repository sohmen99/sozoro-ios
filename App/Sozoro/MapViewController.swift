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
        map.addAnnotations(store.landmarks.map { CrowdPin(spot: $0, crowd: store.crowdLevel($0)) })
        if demo.on {
            // デモでは地図を叩いた場所に立つ。実測は起こさない。
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            map.addGestureRecognizer(tap)
        }
        addMeMarker()

        sheet.onBegin = { [weak self] in self?.onBegin?() }
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
    }

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
        if demo.on { meMarker.map { map.removeAnnotation($0) }; addMeMarker() }
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

final class CrowdPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let crowd: Int
    init(spot: Spot, crowd: Int) {
        coordinate = CLLocationCoordinate2D(latitude: spot.coordinate.lat,
                                            longitude: spot.coordinate.lon)
        title = nil            // 名前は出さない。行き先を示唆しないため。
        self.crowd = crowd
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ m: MKMapView, viewFor a: MKAnnotation) -> MKAnnotationView? {
        guard let p = a as? CrowdPin else { return nil }
        let id = "crowd"
        let v = m.dequeueReusableAnnotationView(withIdentifier: id)
            ?? MKAnnotationView(annotation: a, reuseIdentifier: id)
        v.annotation = a
        v.frame = CGRect(x: 0, y: 0, width: 11, height: 11)
        v.backgroundColor = Theme.crowdColour(p.crowd)
        v.layer.cornerRadius = 5.5
        v.layer.borderWidth = 1.4
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        v.canShowCallout = false
        return v
    }
}

