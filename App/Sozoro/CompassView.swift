import UIKit
import SozoroCore

/// コンパスの文字盤。針は片側だけ。追う先を取り違えないように、反対の端は短い重りにする。
/// 角度は足しこむので、北をまたいでも逆回りしない。
/// コンパスの文字盤。ウェブ版の 300×300 の図をそのまま起こしてある。
/// 外輪・内輪・点線の輪・四方の目盛りと文字・進捗の輪、そして片側だけの針。
final class CompassDial: UIView {
    private let rings = CAShapeLayer()
    private let ticks = CAShapeLayer()
    private let dashed = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let needle = CALayer()
    private let label = makeLabel("THIS WAY", Theme.mono(9, .semibold), Theme.quietDk, align: .center)
    private var marks: [UILabel] = []
    private var shown: Double = 0
    /// ウェブ版の図と同じ座標系で組んで、最後に縮める。ズレの元を作らない。
    private static let box: CGFloat = 300

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        [rings, dashed, ticks, progress].forEach { layer.addSublayer($0) }
        layer.addSublayer(needle)
        for t in ["N", "E", "S", "W"] {
            let l = makeLabel(t, Theme.mono(11), Theme.mutedDark, align: .center)
            addSubview(l); marks.append(l)
        }
        addSubview(label)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let c = CGPoint(x: 150, y: 150)
        // 外輪 142 / 内輪 112。ウェブ版と同じ半径。
        let r = UIBezierPath(arcCenter: c, radius: 142, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        r.append(UIBezierPath(arcCenter: c, radius: 112, startAngle: 0, endAngle: .pi * 2, clockwise: true))
        rings.path = r.cgPath
        rings.fillColor = nil; rings.strokeColor = Theme.hairlineDk.cgColor; rings.lineWidth = 1

        let d = UIBezierPath(arcCenter: c, radius: 86, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        dashed.path = d.cgPath
        dashed.fillColor = nil; dashed.strokeColor = Theme.sumi3.cgColor
        dashed.lineWidth = 1; dashed.lineDashPattern = [1, 7]; dashed.lineCap = .round

        // 四方の目盛りと、斜め45度の短い印。
        let t = UIBezierPath()
        t.move(to: CGPoint(x: 150, y: 8));   t.addLine(to: CGPoint(x: 150, y: 22))
        t.move(to: CGPoint(x: 150, y: 278)); t.addLine(to: CGPoint(x: 150, y: 292))
        t.move(to: CGPoint(x: 8, y: 150));   t.addLine(to: CGPoint(x: 22, y: 150))
        t.move(to: CGPoint(x: 278, y: 150)); t.addLine(to: CGPoint(x: 292, y: 150))
        t.move(to: CGPoint(x: 50, y: 50));   t.addLine(to: CGPoint(x: 59, y: 59))
        t.move(to: CGPoint(x: 250, y: 50));  t.addLine(to: CGPoint(x: 241, y: 59))
        t.move(to: CGPoint(x: 50, y: 250));  t.addLine(to: CGPoint(x: 59, y: 241))
        t.move(to: CGPoint(x: 250, y: 250)); t.addLine(to: CGPoint(x: 241, y: 241))
        ticks.path = t.cgPath
        ticks.fillColor = nil; ticks.strokeColor = Theme.ink2.cgColor
        ticks.lineWidth = 1; ticks.lineCap = .round

        progress.path = UIBezierPath(arcCenter: c, radius: 142, startAngle: -.pi / 2,
                                     endAngle: .pi * 1.5, clockwise: true).cgPath
        progress.fillColor = nil; progress.strokeColor = Theme.quietDk.cgColor
        progress.lineWidth = 2; progress.lineCap = .round; progress.strokeEnd = 0

        buildNeedle()
    }

    /// 針。ウェブ版と同じ長さで、行き先側だけを矢にする。
    private func buildNeedle() {
        let tail = CAShapeLayer()
        tail.path = UIBezierPath(roundedRect: CGRect(x: -1.5, y: 6, width: 3, height: 46),
                                 cornerRadius: 1.5).cgPath
        tail.fillColor = Theme.mutedDark.withAlphaComponent(0.5).cgColor

        let shaft = CAShapeLayer()
        shaft.path = UIBezierPath(roundedRect: CGRect(x: -2.5, y: -88, width: 5, height: 88),
                                  cornerRadius: 2.5).cgPath
        shaft.fillColor = Theme.quietDk.cgColor

        let head = CAShapeLayer()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 0, y: -128)); p.addLine(to: CGPoint(x: 17, y: -84))
        p.addLine(to: CGPoint(x: 0, y: -92)); p.addLine(to: CGPoint(x: -17, y: -84))
        p.close()
        head.path = p.cgPath; head.fillColor = Theme.quietDk.cgColor

        let bead = CAShapeLayer()
        bead.path = UIBezierPath(ovalIn: CGRect(x: -4, y: -68, width: 8, height: 8)).cgPath
        bead.fillColor = Theme.sumi.cgColor
        bead.strokeColor = Theme.quietDk.cgColor; bead.lineWidth = 2

        let hub = CAShapeLayer()
        hub.path = UIBezierPath(ovalIn: CGRect(x: -4, y: -4, width: 8, height: 8)).cgPath
        hub.fillColor = Theme.sumi.cgColor
        hub.strokeColor = Theme.quietDk.cgColor; hub.lineWidth = 2

        [tail, shaft, head, bead, hub].forEach { needle.addSublayer($0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 300 の座標系で組んだものを、いまの大きさに合わせて縮める。
        let side = min(bounds.width, bounds.height)
        let k = side / Self.box
        let ox = (bounds.width - side) / 2, oy = (bounds.height - side) / 2
        let fit = CATransform3DConcat(CATransform3DMakeScale(k, k, 1),
                                      CATransform3DMakeTranslation(ox, oy, 0))
        [rings, dashed, ticks, progress].forEach {
            $0.frame = bounds; $0.transform = fit
        }
        // 針は中心を軸に回すので、位置だけ合わせて拡大は別に持つ。
        needle.position = CGPoint(x: ox + side / 2, y: oy + side / 2)
        needle.bounds = .zero
        applyNeedleTransform()

        let c = CGPoint(x: ox + side / 2, y: oy + side / 2)
        let rr = 142 * k
        let places: [(CGFloat, CGFloat)] = [(0, -rr - 2), (rr + 2, 0), (0, rr + 2), (-rr - 2, 0)]
        for (i, l) in marks.enumerated() {
            l.sizeToFit()
            l.center = CGPoint(x: c.x + places[i].0, y: c.y + places[i].1)
        }
        label.sizeToFit()
        label.center = CGPoint(x: c.x, y: c.y - 40 * k)
    }

    private var scale: CGFloat { min(bounds.width, bounds.height) / Self.box }

    private func applyNeedleTransform() {
        let k = scale
        needle.transform = CATransform3DConcat(
            CATransform3DMakeScale(k, k, 1),
            CATransform3DMakeRotation(CGFloat(shown * .pi / 180), 0, 0, 1))
    }

    /// 差を -180〜180 に畳んでから足す。359°から1°へ動くとき一周しない。
    func point(to rotation: Double, progressValue: Double?) {
        let delta = ((rotation - shown).truncatingRemainder(dividingBy: 360) + 540)
                        .truncatingRemainder(dividingBy: 360) - 180
        shown += delta
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        applyNeedleTransform()
        progress.strokeEnd = CGFloat(progressValue ?? 0)
        CATransaction.commit()
        // 文字は回さない。南を向いたとき逆さになるので。
        UIView.animate(withDuration: 0.25) { self.label.transform = .identity }
    }
}

/// 歩いている画面。方角と残り距離だけ。行き先の名前は出さない。
final class CompassViewController: UIViewController {
    private let store: WalkStore
    private let dial = CompassDial()
    private let head = makeLabel("We are not telling you yet", Theme.display(19), .white, align: .center)
    private let sub = makeLabel("", Theme.body(12), Theme.mutedDark, align: .center)
    private let distValue = makeLabel("—", Theme.mono(22, .semibold), .white, align: .center)
    private let minsValue = makeLabel("—", Theme.mono(22, .semibold), .white, align: .center)
    private let brgValue  = makeLabel("—", Theme.mono(22, .semibold), .white, align: .center)
    private let arriveButton = UIButton(type: .system)

    init(store: WalkStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    var onArrive: (() -> Void)?
    var onGiveUp: (() -> Void)?
    /// デモのときだけ出す。行き先へ自動で歩く。
    var demoWalk: (() -> Void)?
    private let hintCard = HintCard()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Theme.quietDk
        cfg.baseForegroundColor = Theme.sumi
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 13, leading: 16, bottom: 13, trailing: 16)
        arriveButton.configuration = cfg
        // 着いていないのに押して終わってしまうのを防ぐ。遠いときだけ確認する。
        arriveButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.store.arrived { self.onArrive?(); return }
            let left = Int((self.store.remaining ?? 0).rounded())
            let a = UIAlertController(
                title: "You are still \(left) m away",
                message: "Ending here counts as arriving. Do it anyway?",
                preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Keep walking", style: .cancel))
            a.addAction(UIAlertAction(title: "End here", style: .destructive) { _ in
                self.onArrive?()
            })
            self.present(a, animated: true)
        }, for: .touchUpInside)

        let giveUp = UIButton(type: .system)
        giveUp.setTitle("Give up", for: .normal)
        giveUp.titleLabel?.font = Theme.body(12)
        giveUp.tintColor = Theme.mutedDark
        giveUp.addAction(UIAction { [weak self] _ in self?.onGiveUp?() }, for: .touchUpInside)

        dial.translatesAutoresizingMaskIntoConstraints = false
        dial.heightAnchor.constraint(equalToConstant: 290).isActive = true

        let metrics = stack(.horizontal, 22, [
            metric(distValue, "LEFT"), metric(minsValue, "ON FOOT"), metric(brgValue, "BEARING")
        ])
        metrics.distribution = .fillEqually

        hintCard.onUse = { [weak self] in
            guard let self else { return }
            self.store.hintsUsed = min(2, self.store.hintsUsed + 1)
            self.refresh()
        }
        var rows: [UIView] = [stack(.vertical, 5, [head, sub]), dial, metrics, hintCard, arriveButton]
        if demoWalk != nil {
            let w = UIButton(type: .system)
            w.setTitle("Walk to it (demo)", for: .normal)
            w.titleLabel?.font = Theme.body(13, .semibold)
            w.tintColor = Theme.mid
            w.addAction(UIAction { [weak self] _ in self?.demoWalk?() }, for: .touchUpInside)
            rows.append(w)
        }
        rows.append(giveUp)
        let col = stack(.vertical, 20, rows)
        view.addSubview(col)
        col.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            col.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        refresh()
    }

    private func metric(_ value: UILabel, _ key: String) -> UIView {
        let k = UILabel(); k.attributedText = Theme.label(key); k.textAlignment = .center
        return stack(.vertical, 3, [value, k])
    }

    func refresh() {
        guard let h = store.here, let d = store.destination else { return }
        let bearing = Geo.bearing(h, d.coordinate)
        let rot = store.heading == nil ? bearing : bearing - store.heading!
        var p: Double?
        if let o = store.origin {
            let total = Geo.distance(o, d.coordinate)
            if total > 1, let r = store.remaining { p = min(1, max(0, 1 - r / total)) }
        }
        dial.point(to: rot, progressValue: p)

        let r = store.remaining ?? 0
        distValue.text = r >= 2000 ? String(format: "%.1fkm", r / 1000)
                                   : "\(Int((r / 10).rounded()) * 10)m"
        minsValue.text = "\(store.minutesLeft)"
        brgValue.text = String(format: "%03.0f°", bearing)

        let dir = Geo.compassEN[Geo.compassIndex(bearing)]
        sub.text = store.heading == nil
            ? "Follow the green tip. Something quiet, \(dir) of here. The dial is north-up."
            : "Follow the green tip. Something quiet, \(dir) of here."

        hintCard.render(store: store)
        let there = store.arrived
        arriveButton.configuration?.attributedTitle = AttributedString(
            there ? "You made it" : "I'm here",
            attributes: AttributeContainer([.font: Theme.body(16, .semibold)]))
        arriveButton.configuration?.baseBackgroundColor = there ? Theme.quietDk : Theme.sumi3
        arriveButton.configuration?.baseForegroundColor = there ? Theme.sumi : .white
    }
}

/// ヒントは2回。迷って欲しくなったら使う。
/// 1回目で種類、2回目で混み具合と頭の一文字。名前そのものは最後まで出さない。
final class HintCard: UIView {
    var onUse: (() -> Void)?
    private let button = UIButton(type: .system)
    private let body = UIStackView()
    private let empty = makeLabel("Two hints. Spend them when you are lost enough to want one.",
                                  Theme.body(11.5), Theme.mutedDark, lines: 0)

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.sumi2
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Theme.hairlineDk.cgColor

        var c = UIButton.Configuration.plain()
        c.image = UIImage(systemName: "lightbulb")
        c.imagePadding = 6
        c.baseForegroundColor = Theme.aiLight
        c.contentInsets = .init(top: 8, leading: 10, bottom: 8, trailing: 10)
        button.configuration = c
        button.addAction(UIAction { [weak self] _ in self?.onUse?() }, for: .touchUpInside)

        body.axis = .vertical; body.spacing = 5
        let col = stack(.vertical, 8, [
            stack(.horizontal, 8, [UIView(), button], align: .center), empty, body
        ])
        addSubview(col)
        col.pin(to: self, insets: .init(top: 10, left: 13, bottom: 12, right: 13))
    }
    required init?(coder: NSCoder) { fatalError() }

    func render(store: WalkStore) {
        body.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let used = store.hintsUsed
        button.configuration?.attributedTitle = AttributedString(
            used >= 2 ? "No hints left" : "Use a hint (\(2 - used) left)",
            attributes: AttributeContainer([.font: Theme.body(12, .semibold)]))
        button.isEnabled = used < 2
        button.alpha = used < 2 ? 1 : 0.45
        empty.isHidden = used > 0
        guard let d = store.destination else { return }
        if used >= 1 { body.addArrangedSubview(line("What it is", store.category(d))) }
        if used >= 2 {
            let v = store.crowd.level(d, at: store.clock())
            body.addArrangedSubview(line("How busy", "\(v)% of peak"))
            body.addArrangedSubview(line("First letter", store.firstLetter(d)))
        }
    }

    private func line(_ k: String, _ v: String) -> UIView {
        let key = UILabel(); key.attributedText = Theme.label(k)
        key.setContentHuggingPriority(.required, for: .horizontal)
        return stack(.horizontal, 10, [key, UIView(),
                                       makeLabel(v, Theme.body(12.5, .semibold), .white)],
                     align: .firstBaseline)
    }
}
