import CoreLocation
import Combine
import SozoroCore

/// CLLocationManager の薄い包み。ウェブ版でいちばん不安定だったところ。
/// 許可は一度、方位は真北基準、精度も更新頻度もブラウザとは桁が違う。
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var coordinate: Coordinate?
    @Published var accuracy: Double?
    /// 真北からの度。取れないときは nil にして、文字盤を北固定にする。
    @Published var heading: Double?
    @Published var authorized = false
    @Published var message: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.headingFilter = 2
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            message = "Location is switched off. Turn it on in Settings."
        default: break
        }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }
        let c = Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
        let a = l.horizontalAccuracy
        Task { @MainActor in
            self.coordinate = c; self.accuracy = a; self.message = nil
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        // 真北が取れないときは磁北で代用しない。北固定のほうが嘘が少ない。
        let v = h.trueHeading >= 0 ? h.trueHeading : nil
        Task { @MainActor in self.heading = v }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let ok = m.authorizationStatus == .authorizedWhenInUse || m.authorizationStatus == .authorizedAlways
        Task { @MainActor in
            self.authorized = ok
            if ok { m.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError e: Error) {
        Task { @MainActor in self.message = "No fix yet. This works better outdoors." }
    }
}
