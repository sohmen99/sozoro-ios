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
    /// シミュレーションに入った直後だけ、盤を開いた状態で見せる。
    /// 畳んだ一行だけを置いても、そこが操作盤だと分からない。
    var openPanelOnAppear = false

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
        map.showsUserLocation = false   // 自前の印を出す
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

        refreshHeat()

        if demo.on {
            // デモでは地図を叩いた場所に立つ。実測は起こさない。
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            map.addGestureRecognizer(tap)
        }
        addMeMarker()

        sheet.onBegin = { [weak self] in self?.onBegin?() }
        sheet.onSlide = { [weak self] _ in self?.layoutOffArea() }
        view.addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 22)
        ])

        view.addSubview(offArea)
        offArea.translatesAutoresizingMaskIntoConstraints = false
        offArea.isHidden = true

        let bar = stack(.horizontal, 8, [
            roundButton("chevron.left") { [weak self] in self?.onCover?() },
            UIView(),
            // 困ったときの窓口。プライバシーと問い合わせ先を1枚にまとめたページ。
            roundButton("questionmark") {
                URL(string: "https://sites.google.com/view/tokyo-sozoro-sup-privacy")
                    .map { UIApplication.shared.open($0) }
            },
            roundButton("seal") { [weak self] in self?.onRewards?() },
            simButton
        ], align: .center)
        view.addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])

        if demo.on {
            panel.onChange = { [weak self] in self?.locationMoved(); self?.refreshHeat() }
            panel.onExit = { [weak self] in self?.onDemoToggle?(false) }
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
        sheet.foot.update(from: map)

        if demo.on, openPanelOnAppear {
            openPanelOnAppear = false
            panel.setExpanded(true, animated: false)
            // どこが操作盤かを一度だけ言う。次からは畳んだ一行だけ。
            store.toast("Simulation mode. Tap the red bar to open or close the controls.",
                        "シミュレーションモード。赤い帯を叩くと操作盤が開きます。")
        }
    }

    private var detail: LandmarkDetailView?
    private var detailScrim: UIView?
    private var meMarker: MeAnnotation?
    private func addMeMarker() {
        guard let h = store.here else { return }
        let a = MeAnnotation(coordinate: CLLocationCoordinate2D(latitude: h.lat, longitude: h.lon),
                             demo: demo.on)
        map.addAnnotation(a)
        meMarker = a
    }
    private var framed = false
    /// シートが画面の下半分を覆うので、素直に中心を置くと上野も浅草も
    /// 板の下に隠れて、ヒートが見えているのに見えない状態になる。
    /// 立っている場所と混雑の中心が、シートの上の帯に収まるように寄せる。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // シートの高さが決まる前に呼ばれると枠がずれる。決まってから一度だけ。
        guard !framed, view.bounds.height > 0, sheet.bounds.height > 0 else { return }
        framed = true
        // 見せる幅をこちらで決める。edgePadding で合わせると、シートの高さ次第で
        // 何kmになるか分からず、外枠や引きの上限に切られた結果を見ることになる。
        //
        // 横 4.5km。台東区の幅がちょうど画面いっぱいに入る。
        // シートが下半分を覆うので、その上の帯の真ん中に上野・浅草が来るよう
        // 地図の中心を南へずらす。
        let wideM = 4500.0
        let hot = Coordinate(lat: 35.7143, lon: 139.7860)      // 上野と浅草のあいだ
        let top = 96.0, sheetH = Double(sheet.bounds.height)
        let viewH = Double(view.bounds.height), viewW = Double(view.bounds.width)
        let bandMid = (top + (viewH - sheetH)) / 2
        let shiftPt = viewH / 2 - bandMid                       // 中心から帯の中心までの差
        let mPerPt = wideM / viewW
        let lat = hot.lat - (shiftPt * mPerPt) / 111132
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: hot.lon),
            latitudinalMeters: wideM * viewH / viewW, longitudinalMeters: wideM), animated: false)

        // 外枠は、決めた枠取りを基準にして張る。先に張ると、南へずらしたぶんが
        // 枠の外に出て、収めるために勝手に寄ってしまう。
        // 横は行き先・基準地点・駅が全部入る 9km。縦は見えている高さ＋少し。
        let shown = map.region
        map.setCameraBoundary(MKMapView.CameraBoundary(coordinateRegion: MKCoordinateRegion(
            center: shown.center,
            latitudinalMeters: shown.span.latitudeDelta * 111132 + 3000,
            longitudinalMeters: 9000)), animated: false)
        map.setCameraZoomRange(MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 900,
            maxCenterCoordinateDistance: map.camera.centerCoordinateDistance * 1.35),
                               animated: false)
    }

    /// 気分や歩き方が変わったとき。地図はそのままで、シートだけ描き直す。
    func storeChanged() {
        sheet.refresh()
        refreshOffArea()
    }

    /// 現在地だけ動かす。地図を作り直さない。
    private func moveMeMarker() {
        guard let h = store.here else { return }
        guard let m = meMarker, m.demo == demo.on else {
            meMarker.map { map.removeAnnotation($0) }
            addMeMarker(); return
        }
        m.coordinate = CLLocationCoordinate2D(latitude: h.lat, longitude: h.lon)
    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        let p = g.location(in: map)
        let c = map.convert(p, toCoordinateFrom: map)
        store.here = Coordinate(lat: c.latitude, lon: c.longitude)
        // 立ち位置が変わったら、区の外の帯もその場で見直す。
        // ここで sheet だけ描き直していたので、区の中に置いても帯が残っていた。
        locationMoved()
    }

    /// 時刻が変わると混み具合も変わる。にじみも基準地点の点も入れ替える。
    func refreshHeat() {
        map.overlays.forEach { map.removeOverlay($0) }
        map.addOverlay(HeatOverlay(landmarks: Landmark.all, crowd: store.crowd, now: store.clock()),
                       level: .aboveRoads)
        let pins = map.annotations.compactMap { $0 as? LandmarkPin }
        map.removeAnnotations(pins)
        map.addAnnotations(Landmark.all.map {
            LandmarkPin(landmark: $0, crowd: store.crowd.level($0.asSpot, at: store.clock()))
        })
    }

    func locationMoved() {
        sheet.refresh()
        refreshOffArea()
        moveMeMarker()
    }

    /// 区の外にいるとき。行き先の母集団が台東区と荒川区に寄っているので、
    /// 遠くから開いた人には、いちばん近い基準地点との関係で位置を伝える。
    private let offArea = OffAreaBanner()
    /// シミュレーションの入り口。区の外にいるときは赤くする。
    /// ここを押してもらわないと、外にいる人は何もできない。
    private lazy var simButton: UIButton = roundButton(
        demo.on ? "wand.and.stars.inverse" : "wand.and.stars") { [weak self] in
            guard let self else { return }
            self.onDemoToggle?(!self.demo.on)
        }

    private func layoutOffArea() {
        // どちらも同じ親に入っていないと張れない。入る前に呼ばれたら何もしない。
        guard offArea.superview === view, sheet.superview === view else { return }
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
        // 区の中に戻ったら、帯もボタンの色も元に戻す。
        func calm() {
            offArea.isHidden = true
            simButton.configuration?.baseBackgroundColor = Theme.washi.withAlphaComponent(0.92)
            simButton.configuration?.baseForegroundColor = Theme.ink
        }
        guard let h = store.here else { calm(); return }
        if Ward.taito.contains(h) { calm(); return }
        // どこまで何km、は言わない。ここから歩ける場所は無いので、数字は役に立たない。
        // やることだけ書く。押せばそのまま入れる。
        offArea.set(title: store.t("You are outside Taito", "台東区の外にいます"),
                    body: store.t(
                        "Nothing here to walk to. Turn on Simulation mode to stand in Ueno "
                      + "and play from anywhere — then tap the map to move.",
                        "ここから歩ける場所はありません。シミュレーションモードを入れると上野に立てて、"
                      + "どこにいても遊べます。地図を叩けばその場所に移れます。"),
                    action: store.t("Turn on Simulation mode", "シミュレーションモードを入れる"))
        offArea.onTap = { [weak self] in self?.onDemoToggle?(true) }
        offArea.isHidden = false
        // 杖のボタンも赤くする。帯とボタンが同じ色なら、どれを押すのか迷わない。
        simButton.configuration?.baseBackgroundColor = Theme.busy
        simButton.configuration?.baseForegroundColor = .white
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
        let all = stack(.vertical, 10, [row, actionLabel])
        addSubview(all)
        all.pin(to: self, insets: .init(top: 12, left: 13, bottom: 12, right: 13))

        // 読むだけの帯だと、外にいる人はここで詰む。押せば入れるようにする。
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    required init?(coder: NSCoder) { fatalError() }

    private let actionLabel: UILabel = {
        let l = makeLabel("", Theme.body(13, .semibold), .white, align: .center)
        l.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        l.layer.cornerRadius = 9
        l.layer.cornerCurve = .continuous
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        l.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return l
    }()
    var onTap: (() -> Void)?
    @objc private func tapped() { onTap?() }

    func set(title: String, body: String, action: String) {
        titleLabel.text = title; bodyLabel.text = body; actionLabel.text = action
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
    func mapView(_ m: MKMapView, regionDidChangeAnimated: Bool) { sheet.foot.update(from: m) }

    func mapView(_ m: MKMapView, rendererFor o: MKOverlay) -> MKOverlayRenderer {
        o is HeatOverlay ? HeatRenderer(overlay: o) : MKOverlayRenderer(overlay: o)
    }

    func mapView(_ m: MKMapView, viewFor a: MKAnnotation) -> MKAnnotationView? {
        if a is MeAnnotation {
            let id = "me"
            let v = m.dequeueReusableAnnotationView(withIdentifier: id) as? MeView
                ?? MeView(annotation: a, reuseIdentifier: id)
            v.annotation = a
            return v
        }
        if let p = a as? LandmarkPin {
            let id = "landmark"
            let v = m.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: a, reuseIdentifier: id)
            v.annotation = a
            v.canShowCallout = false
            v.subviews.forEach { $0.removeFromSuperview() }
            // ウェブ版と同じ。白い丸に線画、右上に混み具合の点。
            v.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
            v.backgroundColor = .white
            v.layer.cornerRadius = 17
            v.layer.borderWidth = 1
            v.layer.borderColor = Theme.hairline.cgColor
            v.layer.shadowColor = UIColor(hex: 0x14171C).cgColor
            v.layer.shadowOpacity = 0.16
            v.layer.shadowRadius = 3
            v.layer.shadowOffset = CGSize(width: 0, height: 2)
            let icon = IconView(p.landmark.icon, size: 17, colour: Theme.ink2)
            icon.center = CGPoint(x: 17, y: 17)
            icon.translatesAutoresizingMaskIntoConstraints = true
            v.addSubview(icon)
            let dot = UIView(frame: CGRect(x: 23, y: -2, width: 11, height: 11))
            dot.backgroundColor = Theme.crowdColour(p.crowd)
            dot.layer.cornerRadius = 5.5
            dot.layer.borderWidth = 2
            dot.layer.borderColor = UIColor.white.cgColor
            v.addSubview(dot)
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

    @objc func closeDetail() {
        let d = detail, s = detailScrim
        detail = nil; detailScrim = nil
        UIView.animate(withDuration: 0.18) {
            d?.alpha = 0; s?.alpha = 0
            d?.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in d?.removeFromSuperview(); s?.removeFromSuperview() }
    }

    func showDetail(_ l: Landmark) {
        closeDetail()
        let d = LandmarkDetailView(landmark: l, crowd: store.crowd, now: store.clock(), lang: store.lang)
        d.onClose = { [weak self] in self?.closeDetail() }
        // 背景を暗くして、外を叩いても閉じられるようにする。
        let scrim = UIView()
        scrim.backgroundColor = UIColor(hex: 0x14171C, alpha: 0.38)
        view.addSubview(scrim)
        scrim.pin(to: view)
        scrim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeDetail)))
        detailScrim = scrim

        view.addSubview(d)
        view.bringSubviewToFront(d)          // フォームより前。重なってよい。
        d.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            d.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            d.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            d.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        d.alpha = 0
        d.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        scrim.alpha = 0
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            d.alpha = 1; d.transform = .identity; scrim.alpha = 1
        }
        detail = d
    }
}

