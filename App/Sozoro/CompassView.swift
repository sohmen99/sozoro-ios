import UIKit
import SozoroCore

/// コンパスの文字盤。針は片側だけ。追う先を取り違えないように、反対の端は短い重りにする。
/// 角度は足しこむので、北をまたいでも逆回りしない。
final class CompassDial: UIView {
    private let needle = CALayer()
    private let ring = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let label = makeLabel("THIS WAY", Theme.mono(9, .semibold), Theme.quietDk, align: .center)
    private var shown: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.addSublayer(ring)
        layer.addSublayer(progress)
        layer.addSublayer(needle)
        addSubview(label)
        buildNeedle()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildNeedle() {
        // 重り。行き先とまちがえないよう短く暗く。
        let tail = CAShapeLayer()
        tail.path = UIBezierPath(roundedRect: CGRect(x: -1.5, y: 4, width: 3, height: 44),
                                 cornerRadius: 1.5).cgPath
        tail.fillColor = Theme.mutedDark.withAlphaComponent(0.55).cgColor
        // 追う先。
        let shaft = CAShapeLayer()
        shaft.path = UIBezierPath(roundedRect: CGRect(x: -2.5, y: -86, width: 5, height: 86),
                                  cornerRadius: 2.5).cgPath
        shaft.fillColor = Theme.quietDk.cgColor
        let head = CAShapeLayer()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 0, y: -118)); p.addLine(to: CGPoint(x: 13, y: -86))
        p.addLine(to: CGPoint(x: 0, y: -94)); p.addLine(to: CGPoint(x: -13, y: -86))
        p.close()
        head.path = p.cgPath; head.fillColor = Theme.quietDk.cgColor
        let bead = CAShapeLayer()
        bead.path = UIBezierPath(ovalIn: CGRect(x: -4.5, y: -68, width: 9, height: 9)).cgPath
        bead.fillColor = Theme.sumi.cgColor
        bead.strokeColor = Theme.quietDk.cgColor
        bead.lineWidth = 2
        [tail, shaft, head, bead].forEach { needle.addSublayer($0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let r = min(bounds.width, bounds.height) / 2 - 8
        ring.path = UIBezierPath(arcCenter: c, radius: r, startAngle: 0,
                                 endAngle: .pi * 2, clockwise: true).cgPath
        ring.strokeColor = Theme.hairlineDk.cgColor
        ring.fillColor = nil; ring.lineWidth = 1
        progress.path = ring.path
        progress.strokeColor = Theme.quietDk.cgColor
        progress.fillColor = nil; progress.lineWidth = 3
        progress.lineCap = .round
        progress.transform = CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)
        // 回転の中心が図の中心になるよう、レイヤーを合わせておく
        progress.frame = bounds
        progress.path = UIBezierPath(arcCenter: c, radius: r, startAngle: -.pi / 2,
                                     endAngle: .pi * 1.5, clockwise: true).cgPath
        progress.transform = CATransform3DIdentity
        needle.frame = CGRect(x: c.x, y: c.y, width: 0, height: 0)
        label.sizeToFit()
        label.center = CGPoint(x: c.x, y: c.y - 38)
    }

    /// 差を -180〜180 に畳んでから足す。359°から1°へ動くとき一周しない。
    func point(to rotation: Double, progressValue: Double?) {
        let delta = ((rotation - shown).truncatingRemainder(dividingBy: 360) + 540)
                        .truncatingRemainder(dividingBy: 360) - 180
        shown += delta
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        needle.transform = CATransform3DMakeRotation(CGFloat(shown * .pi / 180), 0, 0, 1)
        progress.strokeEnd = CGFloat(progressValue ?? 0)
        CATransaction.commit()
        // 文字だけは回さず立てておく。南を向いたとき逆さになるので。
        UIView.animate(withDuration: 0.25) {
            self.label.transform = .identity
        }
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Theme.quietDk
        cfg.baseForegroundColor = Theme.sumi
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 13, leading: 16, bottom: 13, trailing: 16)
        arriveButton.configuration = cfg
        arriveButton.addAction(UIAction { [weak self] _ in self?.onArrive?() }, for: .touchUpInside)

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

        let col = stack(.vertical, 20, [
            stack(.vertical, 5, [head, sub]), dial, metrics, arriveButton, giveUp
        ])
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

        let there = store.arrived
        arriveButton.configuration?.attributedTitle = AttributedString(
            there ? "You made it" : "I'm here",
            attributes: AttributeContainer([.font: Theme.body(16, .semibold)]))
        arriveButton.configuration?.baseBackgroundColor = there ? Theme.quietDk : Theme.sumi3
        arriveButton.configuration?.baseForegroundColor = there ? Theme.sumi : .white
    }
}

#Preview("Compass") {
    CompassViewController(store: .preview(stage: .walking))
}
