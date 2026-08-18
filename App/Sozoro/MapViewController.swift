import UIKit
import MapKit
import SozoroCore

/// 表に出ている画面。混雑の地図と、その下から引き出すシート。
/// 混雑を見てから歩き方を決める、という順番はウェブ版と同じ。
@MainActor
final class MapViewController: UIViewController {
    let store: WalkStore
    private lazy var location = LocationService()

    private let map = MKMapView()
    private lazy var sheet = SheetView(store: store)
    private var child: UIViewController?

    init(store: WalkStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    convenience init() { self.init(store: WalkStore()) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.washi

        map.mapType = .mutedStandard
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        map.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.7138, longitude: 139.7772),
            span: MKCoordinateSpan(latitudeDelta: 0.032, longitudeDelta: 0.032))
        map.delegate = self
        view.addSubview(map)
        map.pin(to: view)
        dropCrowdPins()

        sheet.onBegin = { [weak self] in self?.store.begin() }
        view.addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 22)
        ])

        store.onChange = { [weak self] in self?.render() }
        location.onUpdate = { [weak self] c, h in
            guard let self else { return }
            self.store.here = c
            self.store.heading = h
            if let c, self.store.stage == .planning {
                self.map.setCenter(CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon),
                                   animated: true)
            }
            self.sheet.refresh()
            (self.child as? CompassViewController)?.refresh()
        }
        location.start()
    }

    /// 基準地点の混み具合を色の点で置く。ウェブ版のヒートマップにあたる。
    private func dropCrowdPins() {
        map.addAnnotations(store.landmarks.map { s in
            let a = CrowdPin(spot: s, crowd: store.crowdLevel(s))
            return a
        })
    }

    private func render() {
        child?.willMove(toParent: nil)
        child?.view.removeFromSuperview()
        child?.removeFromParent()
        child = nil
        sheet.isHidden = store.stage != .planning
        sheet.refresh()

        let vc: UIViewController?
        switch store.stage {
        case .planning: vc = nil
        case .picking:
            let p = PickViewController(store: store)
            p.onChoose = { [weak self] s in self?.store.choose(s) }
            p.onRedraw = { [weak self] in
                guard let h = self?.store.here else { return }
                self?.store.dealThree(from: h)
            }
            p.onCancel = { [weak self] in self?.store.reset() }
            vc = p
        case .walking:
            let c = CompassViewController(store: store)
            c.onArrive = { [weak self] in self?.store.arrive() }
            c.onGiveUp = { [weak self] in self?.store.reset() }
            vc = c
        case .arrived:
            let a = ArrivalViewController(store: store)
            a.onKeep = { [weak self] in self?.store.next() }
            a.onStop = { [weak self] in self?.store.reset() }
            vc = a
        }
        guard let vc else { return }
        addChild(vc)
        view.addSubview(vc.view)
        vc.view.pin(to: view)
        vc.didMove(toParent: self)
        child = vc
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

#Preview("Map and sheet") { MapViewController(store: .preview()) }
