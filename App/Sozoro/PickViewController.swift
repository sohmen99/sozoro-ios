import UIKit
import SozoroCore

/// 三択。正体は伏せたまま、ぼかした色と一行と距離だけ見せる。
/// 写真が無いときも「はずれ」に見えないよう、色の面で敷く。ウェブ版と同じ考え方。
final class PickCard: UIControl {
    private let thumb = UIView()
    private let teaser = makeLabel("", Theme.body(14.5, .semibold), .white, lines: 0)
    private let meta = makeLabel("", Theme.mono(11.5), Theme.mutedDark, lines: 0)

    init(spot: Spot, teaserText: String, metaText: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor.white.withAlphaComponent(0.045)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.13).cgColor

        thumb.backgroundColor = spot.kind == .food
            ? UIColor(hex: 0x8C5A33) : UIColor(hex: 0x3D5266)
        thumb.layer.cornerRadius = 10
        thumb.layer.cornerCurve = .continuous
        thumb.clipsToBounds = true
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.widthAnchor.constraint(equalToConstant: 74).isActive = true
        thumb.heightAnchor.constraint(equalToConstant: 74).isActive = true

        // 色の階調をぼかして敷く。写真が来たら、ここを差し替えるだけ。
        let g = CAGradientLayer()
        g.colors = [UIColor.white.withAlphaComponent(0.28).cgColor,
                    UIColor.black.withAlphaComponent(0.30).cgColor]
        g.startPoint = CGPoint(x: 0.2, y: 0); g.endPoint = CGPoint(x: 0.9, y: 1)
        g.frame = CGRect(x: 0, y: 0, width: 74, height: 74)
        thumb.layer.addSublayer(g)

        let icon = UIImageView(image: UIImage(systemName:
            spot.kind == .food ? "fork.knife" : "building.columns"))
        icon.tintColor = UIColor.white.withAlphaComponent(0.5)
        icon.translatesAutoresizingMaskIntoConstraints = false
        thumb.addSubview(icon)
        icon.centerXAnchor.constraint(equalTo: thumb.centerXAnchor).isActive = true
        icon.centerYAnchor.constraint(equalTo: thumb.centerYAnchor).isActive = true

        teaser.text = teaserText
        meta.text = metaText
        let body = stack(.vertical, 5, [teaser, meta])
        let row = stack(.horizontal, 13, [thumb, body], align: .center)
        row.isUserInteractionEnabled = false
        addSubview(row)
        row.pin(to: self, insets: .init(top: 11, left: 11, bottom: 11, right: 11))
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.72 : 1 }
    }
}

final class PickViewController: UIViewController {
    private let store: WalkStore
    var onChoose: ((Spot) -> Void)?
    var onRedraw: (() -> Void)?
    var onCancel: (() -> Void)?

    init(store: WalkStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi.withAlphaComponent(0.95)

        let eyebrow = UILabel(); eyebrow.attributedText = Theme.label("Three ways from here")
        let title = makeLabel("Pick one. We still will not say.", Theme.display(20), .white, lines: 0)
        let cards = stack(.vertical, 10, store.picks.map { s in
            let c = PickCard(spot: s, teaserText: store.teaser(s), metaText: store.meta(s))
            c.addAction(UIAction { [weak self] _ in self?.onChoose?(s) }, for: .touchUpInside)
            return c
        })

        let note = makeLabel(store.note ?? "You find out what it was by standing in front of it.",
                             Theme.body(11), Theme.muted, lines: 0, align: .center)

        let again = quietButton("Deal again") { [weak self] in self?.onRedraw?() }
        let back  = quietButton("Back") { [weak self] in self?.onCancel?() }

        let col = stack(.vertical, 14, [
            stack(.vertical, 4, [eyebrow, title]), cards,
            stack(.vertical, 9, [again, back, note])
        ])
        view.addSubview(col)
        col.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            col.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func quietButton(_ t: String, _ act: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        var c = UIButton.Configuration.plain()
        c.attributedTitle = AttributedString(t, attributes:
            AttributeContainer([.font: Theme.body(13.5, .medium)]))
        c.baseForegroundColor = .white
        c.background.strokeColor = UIColor.white.withAlphaComponent(0.16)
        c.background.strokeWidth = 1
        c.background.cornerRadius = 10
        c.contentInsets = .init(top: 11, leading: 14, bottom: 11, trailing: 14)
        b.configuration = c
        b.addAction(UIAction { _ in act() }, for: .touchUpInside)
        return b
    }
}

/// 到着。ここで初めて正体を出す。続けるか終えるかを聞く。
final class ArrivalViewController: UIViewController {
    private let store: WalkStore
    var onKeep: (() -> Void)?
    var onStop: (() -> Void)?

    init(store: WalkStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        let eyebrow = UILabel(); eyebrow.attributedText = Theme.label("You made it")
        let head = makeLabel("This is what it was.", Theme.display(26), .white, lines: 0)

        let name = makeLabel(store.destination.map(store.name) ?? "—",
                             Theme.display(21), .white, lines: 0)
        let cat = makeLabel(store.destination?.category ?? "", Theme.body(12), Theme.mutedDark)
        let count = makeLabel("\(store.stops.count) \(store.stops.count == 1 ? "stop" : "stops") so far",
                              Theme.mono(11.5), Theme.muted)

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Theme.quietDk
        cfg.baseForegroundColor = Theme.sumi
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 13, leading: 16, bottom: 13, trailing: 16)
        cfg.attributedTitle = AttributedString(keepTitle, attributes:
            AttributeContainer([.font: Theme.body(16, .semibold)]))
        let keep = UIButton(type: .system)
        keep.configuration = cfg
        keep.addAction(UIAction { [weak self] _ in self?.onKeep?() }, for: .touchUpInside)

        let stop = UIButton(type: .system)
        stop.setTitle("Stop here", for: .normal)
        stop.titleLabel?.font = Theme.body(13)
        stop.tintColor = Theme.mutedDark
        stop.addAction(UIAction { [weak self] _ in self?.onStop?() }, for: .touchUpInside)

        let card = stack(.vertical, 6, [name, cat, count])
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = .init(top: 16, left: 16, bottom: 16, right: 16)
        card.backgroundColor = Theme.sumi2
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous

        let col = stack(.vertical, 18, [stack(.vertical, 4, [eyebrow, head]), card, keep, stop])
        view.addSubview(col)
        col.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            col.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private var keepTitle: String {
        if let c = store.course, c.remaining > 0 { return "Next stop" }
        if store.course != nil { return "Walk again" }
        return "Keep going"
    }
}

#Preview("Three picks") { PickViewController(store: .preview(stage: .picking)) }
#Preview("Arrival")     { ArrivalViewController(store: .preview(stage: .arrived)) }
