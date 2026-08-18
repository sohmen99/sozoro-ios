import UIKit
import SozoroCore
// #Preview が生成する中継コードが SwiftUI を import するので、
// UIKit しか使っていなくてもここで依存に入れておく必要がある。
// 無いと「no such module 'SwiftUI'」でプレビューだけが失敗する。
import SwiftUI

/// 画面をひとつだけ持って、差し替える。遷移はここに集約する。
/// 表紙 → 地図 → 三択 → コンパス → 到着 → 印 の行き来。
@MainActor
final class RootViewController: UIViewController {
    enum Screen { case cover, map, picks, compass, arrival, rewards }

    let store: WalkStore
    let demo: DemoMode
    private var current: UIViewController?
    private var screen: Screen = .cover
    private lazy var location = LocationService()

    init(store: WalkStore, start: Screen = .cover) {
        self.store = store
        self.demo = DemoMode()
        self.screen = start
        super.init(nibName: nil, bundle: nil)
    }
    /// 起動引数で最初の画面を選べる。`-screen map` のように渡す。
    /// シミュレータで一画面だけ見たいときと、画面の写真を撮るときに使う。
    convenience init() {
        var start = Screen.cover
        if let i = CommandLine.arguments.firstIndex(of: "-screen"),
           i + 1 < CommandLine.arguments.count {
            switch CommandLine.arguments[i + 1] {
            case "map":     start = .map
            case "picks":   start = .picks
            case "compass": start = .compass
            case "arrival": start = .arrival
            case "rewards": start = .rewards
            default:        start = .cover
            }
        }
        self.init(store: WalkStore(), start: start)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi
        store.onChange = { [weak self] in self?.followStage() }
        if demo.on {
            // 起動時からデモの場合。トグルで入ったときと同じ状態にしておかないと、
            // 立ち位置も時計も入らず「Looking for you…」のまま止まる。
            if store.here == nil { store.here = Coordinate(lat: 35.7148, lon: 139.7967) }
            store.clock = { [weak self] in self?.demo.now ?? Date() }
        } else {
            location.onUpdate = { [weak self] c, h in
                guard let self else { return }
                self.store.here = c; self.store.heading = h
                (self.current as? MapViewController)?.locationMoved()
                (self.current as? CompassViewController)?.refresh()
            }
            location.start()
        }
        show(screen, animated: false)
    }

    /// 歩く状態が変わったら、対応する画面へ移る。
    /// 気分や歩き方を変えただけのときは、同じ画面のままにする。
    /// 作り直すと地図が再描画されて、見ていた場所が飛ぶ。
    private func followStage() {
        let want: Screen
        switch store.stage {
        case .planning: want = .map
        case .picking:  want = .picks
        case .walking:  want = .compass
        case .arrived:  want = .arrival
        }
        guard want != screen else {
            // 画面はそのままでいい。ただし中身は描き直す。
            // ここを黙って返していたので、気分や歩き方を押しても表示が変わらず、
            // 「押せない」ように見えていた。
            (current as? MapViewController)?.storeChanged()
            return
        }
        show(want)
    }

    func show(_ s: Screen, animated: Bool = true) {
        screen = s
        let vc = make(s)
        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
        let old = current
        current = vc
        guard animated, let old else { old?.view.removeFromSuperview(); old?.removeFromParent(); return }
        vc.view.alpha = 0
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
            vc.view.alpha = 1
            old.view.alpha = 0
        } completion: { _ in
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
    }

    private func make(_ s: Screen) -> UIViewController {
        switch s {
        case .cover:
            let c = CoverViewController(store: store)
            c.onStart = { [weak self] in self?.show(.map) }
            c.onLang = { [weak self] l in
                self?.store.lang = l
                self?.show(.cover, animated: false)     // 言語は全画面に効く
            }
            return c
        case .map:
            let m = MapViewController(store: store, demo: demo)
            m.onBegin = { [weak self] in self?.store.begin() }
            m.onCover = { [weak self] in self?.show(.cover) }
            m.onRewards = { [weak self] in self?.show(.rewards) }
            m.onDemoToggle = { [weak self] on in self?.setDemo(on) }
            return m
        case .picks:
            let p = PickViewController(store: store)
            p.onChoose = { [weak self] sp in self?.store.choose(sp) }
            p.onRedraw = { [weak self] in
                guard let h = self?.store.here else { return }
                self?.store.dealThree(from: h)
            }
            p.onCancel = { [weak self] in self?.store.reset() }
            return p
        case .compass:
            let c = CompassViewController(store: store)
            c.onArrive = { [weak self] in self?.finish() }
            c.onGiveUp = { [weak self] in self?.store.reset() }
            c.demoWalk = demo.on ? { [weak self] in
                guard let self else { return }
                self.demo.walk(store: self.store) { [weak self] in
                    (self?.current as? CompassViewController)?.refresh()
                }
            } : nil
            return c
        case .arrival:
            let a = ArrivalViewController(store: store)
            a.freshSeals = freshSeals
            a.onKeep = { [weak self] in self?.store.next() }
            a.onStop = { [weak self] in self?.store.reset() }
            a.onRewards = { [weak self] in self?.show(.rewards) }
            return a
        case .rewards:
            let r = RewardsViewController(lang: store.lang)
            r.onBack = { [weak self] in self?.followStage() }
            return r
        }
    }

    /// 着いたら記録を1つ残してから到着画面へ。印はここで増える。
    private func finish() {
        let before = WalkLog.shared.earned
        if let d = store.destination, let o = store.origin {
            let destCrowd = store.crowd.level(d, at: demo.on ? demo.now : Date())
            let originSpot = Spot(id: "origin", name: "origin", coordinate: o,
                                  kind: .culture, category: "")
            let originCrowd = store.crowd.level(originSpot, at: demo.on ? demo.now : Date())
            WalkLog.shared.add(Walk(
                startedAt: store.startedAt ?? Date(), arrivedAt: Date(),
                straightM: Geo.distance(o, d.coordinate),
                dispersion: max(0, originCrowd - destCrowd),
                destName: d.name, destKind: d.kind,
                destArea: d.category, destOutsideTaito: false,
                hintsUsed: store.hintsUsed, demo: demo.on))
            store.dispersion = max(0, originCrowd - destCrowd)
        }
        freshSeals = Reward.all.filter {
            WalkLog.shared.earned.contains($0.id) && !before.contains($0.id)
        }
        store.arrive()
    }
    private var freshSeals: [Reward] = []

    private func setDemo(_ on: Bool) {
        demo.on = on
        if on {
            location.stop()
            demo.stop()
            if store.here == nil { store.here = Coordinate(lat: 35.7148, lon: 139.7967) }
            store.clock = { [weak self] in self?.demo.now ?? Date() }
        } else {
            store.clock = { Date() }
            location.start()
        }
        show(.map, animated: false)
    }
}

#Preview("1 Cover")   { RootViewController(store: .preview(), start: .cover) }
#Preview("1 表紙")     { RootViewController(store: .preview(lang: .ja), start: .cover) }
#Preview("2 Map")     { RootViewController(store: .preview(), start: .map) }
#Preview("3 Picks")   { RootViewController(store: .preview(stage: .picking), start: .picks) }
#Preview("4 Compass") { RootViewController(store: .preview(stage: .walking), start: .compass) }
#Preview("5 Arrival") { RootViewController(store: .preview(stage: .arrived), start: .arrival) }
#Preview("6 Marks")   { RootViewController(store: .preview(), start: .rewards) }
