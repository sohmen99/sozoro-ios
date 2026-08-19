import UIKit
import SozoroCore

/// シミュレーションモード。場所と時刻を自由に置いて、外に出ずに通しで見られる。
/// 屋内や審査のときは実測が取れないので、こちらで全画面を確かめられるようにしてある。
@MainActor
final class DemoMode {
    /// 起動引数 `-demo 1` でも入れられる。シミュレータで写真を撮るときに使う。
    var on = CommandLine.arguments.contains("-demo")
    /// 0〜23.5。混雑推定も営業時間もこの時刻に従う。
    var hour: Double = 14
    var weekend = true
    /// 自動歩行の倍率。×60 なら15分が15秒。
    var speed: Double = 60
    private var timer: Timer?

    var now: Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = Int(hour); c.minute = Int((hour - floor(hour)) * 60)
        let base = Calendar.current.date(from: c) ?? Date()
        // 曜日を指定の側へ寄せる。人流の休日昼／平日昼が入れ替わる。
        let wd = Calendar.current.component(.weekday, from: base)
        let isWeekend = (wd == 1 || wd == 7)
        guard isWeekend != weekend else { return base }
        return Calendar.current.date(byAdding: .day, value: weekend ? (7 - wd + 1) : 2, to: base) ?? base
    }

    /// 行き先へ向かって自動で歩く。直線を進むので、道のりぶん遅く進める。
    /// そうしないと「徒歩45分」と出したのに35分で着いてしまう。
    func walk(store: WalkStore, tick: @escaping () -> Void) {
        stop()
        guard store.destination != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let here = store.here, let d = store.destination else { return }
                let step = (store.draw.config.walkSpeed / store.draw.config.detour)
                         * self.speed * (0.25 / 60)
                let left = Geo.distance(here, d.coordinate)
                let brg = Geo.bearing(here, d.coordinate)
                store.heading = brg                      // 針が進行方向を向く
                store.here = Geo.move(from: here, bearing: brg, metres: min(step, left))
                tick()
                if left <= step { self.stop(); tick() }
            }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }
}

/// シミュレーションの操作盤。地図の上に薄く置く。
final class DemoPanel: UIView {
    private let demo: DemoMode
    private let store: WalkStore
    /// つまみの左に出す時刻。動かしている最中に何時なのかが見えないと、
    /// そもそも合わせられない。畳んだときの readout とは別に要る。
    private let hourLabel = makeLabel("14:00", Theme.mono(15, .semibold), .white)
    private let slider = UISlider()
    private let daySeg: UISegmentedControl
    private let speedSeg = UISegmentedControl(items: ["×1", "×10", "×60"])
    var onChange: (() -> Void)?
    /// 盤から抜ける。杖のボタンをもう一度押せば同じことができるが、
    /// 開いている盤の中に出口が無いと、入った人は戻り方を探すことになる。
    var onExit: (() -> Void)?

    init(demo: DemoMode, store: WalkStore) {
        self.demo = demo; self.store = store
        daySeg = UISegmentedControl(items: [store.t("Weekday", "平日"), store.t("Weekend", "休日")])
        super.init(frame: .zero)
        backgroundColor = Theme.sumi
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Theme.mid.withAlphaComponent(0.55).cgColor
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 畳んだ状態。地図の邪魔をしないよう、既定では一行だけにしておく。
    private(set) var expanded = false
    private let body = UIStackView()
    private let summary = makeLabel("", Theme.mono(11), Theme.mid)
    /// 開いたときだけ出す説明。畳んだ一行には入れない。
    private let lede = makeLabel("", Theme.body(10.5), Theme.mutedDark, lines: 0)
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))

    private func build() {
        // 畳んだときは一行に収める。長い見出しを入れると時刻の表示が折れて潰れる。
        // 説明のほうは開いた中に置く。
        let head = UILabel()
        head.attributedText = Theme.label(store.t("Simulation", "シミュレーション"))
        head.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        slider.minimumValue = 0; slider.maximumValue = 23.5; slider.value = 14
        slider.minimumTrackTintColor = Theme.mid
        slider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.demo.hour = (Double(self.slider.value) * 2).rounded() / 2
            self.sync(); self.onChange?()
        }, for: .valueChanged)

        // 選んでいない側の地も塗る。塗らないと地図が透けて読めない。
        daySeg.backgroundColor = Theme.sumi3
        daySeg.selectedSegmentIndex = 1
        daySeg.selectedSegmentTintColor = Theme.mid
        daySeg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        daySeg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        daySeg.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.demo.weekend = self.daySeg.selectedSegmentIndex == 1
            self.sync(); self.onChange?()
        }, for: .valueChanged)

        speedSeg.backgroundColor = Theme.sumi3
        speedSeg.selectedSegmentIndex = 2
        speedSeg.selectedSegmentTintColor = Theme.mid
        speedSeg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        speedSeg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        speedSeg.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.demo.speed = [1.0, 10, 60][self.speedSeg.selectedSegmentIndex]
            self.sync()
        }, for: .valueChanged)


        lede.text = store.t("Place and time are yours. Tap the map to stand there.",
                            "場所も時刻も自由に置けます。地図を叩くと、そこに立ちます。")

        // 時刻はつまみと同じ行に置く。動かしながら見えないと合わせられない。
        hourLabel.setContentHuggingPriority(.required, for: .horizontal)
        hourLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        hourLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        let hourRow = stack(.horizontal, 10, [hourLabel, slider], align: .center)

        let exit = Theme.button(.tertiary,
                                store.t("Leave simulation", "シミュレーションを終わる"),
                                small: true) { [weak self] in self?.onExit?() }

        body.axis = .vertical; body.spacing = 9
        [lede, hourRow, daySeg, speedSeg, exit].forEach { body.addArrangedSubview($0) }

        chevron.tintColor = Theme.mid
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        // 時刻・曜日・倍率は折らない。折れると3行になって畳んだ意味がなくなる。
        summary.numberOfLines = 1
        summary.setContentCompressionResistancePriority(.required, for: .horizontal)
        summary.setContentHuggingPriority(.required, for: .horizontal)
        let headRow = stack(.horizontal, 8, [head, UIView(), summary, chevron], align: .center)
        headRow.isUserInteractionEnabled = true
        headRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggle)))

        let col = stack(.vertical, 9, [headRow, body])
        addSubview(col)
        col.pin(to: self, insets: .init(top: 12, left: 13, bottom: 12, right: 13))
        setExpanded(false, animated: false)
        sync()
    }

    @objc private func toggle() { setExpanded(!expanded, animated: true) }

    func setExpanded(_ on: Bool, animated: Bool) {
        expanded = on
        let apply = {
            self.body.isHidden = !on
            self.body.alpha = on ? 1 : 0
            self.summary.isHidden = on
            self.chevron.transform = CGAffineTransform(rotationAngle: on ? .pi : 0)
        }
        guard animated else { apply(); return }
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
            apply()
            self.superview?.layoutIfNeeded()
        }
    }

    func sync() {
        let h = Int(demo.hour), m = Int((demo.hour - floor(demo.hour)) * 60)
        hourLabel.text = String(format: "%02d:%02d", h, m)
        summary.text = String(format: "%02d:%02d · %@ · ×%.0f", h, m,
                              demo.weekend ? store.t("Weekend", "休日") : store.t("Weekday", "平日"),
                              demo.speed)
    }
}
