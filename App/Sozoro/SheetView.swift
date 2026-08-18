import UIKit
import SozoroCore

/// 地図の下から引き出すシート。混雑を見てから歩き方を決める、という順番はウェブ版のまま。
final class SheetView: UIView {
    private let store: WalkStore
    var onBegin: (() -> Void)?

    private let foodChip = ChipButton(title: "Something to eat", symbol: "fork.knife")
    private let cultChip = ChipButton(title: "Something old", symbol: "building.columns")
    private let wanderRow = ModeRow(title: "Wander", symbol: "die.face.5",
        note: "One stop at a time, about 15 minutes each. Stop whenever you like.")
    private let crossRow = ModeRow(title: "Cross town", symbol: "arrow.triangle.turn.up.right.diamond",
        note: "A fixed line out to a station. Two or three stops, then a train home.")
    private let beginButton = UIButton(type: .system)
    private let noteLabel = makeLabel("", Theme.body(11.5), Theme.muted, lines: 0)
    private let footLabel = makeLabel("", Theme.body(11.5), Theme.muted, lines: 0)

    init(store: WalkStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = Theme.washi
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMaxYCorner.union(.layerMaxXMinYCorner)]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 22
        layer.shadowOffset = CGSize(width: 0, height: -8)
        build()
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let grip = UIView()
        grip.backgroundColor = Theme.hairline
        grip.layer.cornerRadius = 2
        grip.translatesAutoresizingMaskIntoConstraints = false
        grip.heightAnchor.constraint(equalToConstant: 4).isActive = true
        grip.widthAnchor.constraint(equalToConstant: 38).isActive = true
        let gripWrap = UIView()
        gripWrap.addSubview(grip)
        grip.centerXAnchor.constraint(equalTo: gripWrap.centerXAnchor).isActive = true
        grip.topAnchor.constraint(equalTo: gripWrap.topAnchor).isActive = true
        grip.bottomAnchor.constraint(equalTo: gripWrap.bottomAnchor).isActive = true

        let title = makeLabel("Where should we wander?", Theme.display(21), Theme.ink)
        let sub = makeLabel("Tell us what you're after. We draw from the quiet side, and keep the spot to ourselves.",
                            Theme.body(12.5), Theme.muted, lines: 0)

        let lookLabel = UILabel(); lookLabel.attributedText = Theme.label("Looking for")
        let chips = stack(.horizontal, 8, [foodChip, cultChip])
        chips.distribution = .fillEqually
        foodChip.addAction(UIAction { [weak self] _ in self?.store.toggle(.food) }, for: .touchUpInside)
        cultChip.addAction(UIAction { [weak self] _ in self?.store.toggle(.culture) }, for: .touchUpInside)

        let modeLabel = UILabel(); modeLabel.attributedText = Theme.label("How you walk")
        wanderRow.addAction(UIAction { [weak self] _ in self?.store.set(mode: .wander) }, for: .touchUpInside)
        crossRow.addAction(UIAction { [weak self] _ in self?.store.set(mode: .crossTown) }, for: .touchUpInside)

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Theme.ink
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        beginButton.configuration = cfg
        beginButton.addAction(UIAction { [weak self] _ in self?.onBegin?() }, for: .touchUpInside)

        let col = stack(.vertical, 16, [
            gripWrap, stack(.vertical, 3, [title, sub]),
            stack(.vertical, 8, [lookLabel, chips]),
            stack(.vertical, 8, [modeLabel, wanderRow, crossRow, noteLabel]),
            beginButton, footLabel
        ])
        col.setCustomSpacing(20, after: gripWrap)
        addSubview(col)
        col.pin(to: self, insets: .init(top: 12, left: 20, bottom: 20, right: 20))
    }

    func refresh() {
        foodChip.on = store.kinds.contains(.food)
        cultChip.on = store.kinds.contains(.culture)
        wanderRow.on = store.mode == .wander
        crossRow.on = store.mode == .crossTown

        let n = store.wanderCount
        let thin = (n != nil && n! < 3)
        noteLabel.text = thin
            ? "Only \(n!) within 15 minutes of here. Cross town works from anywhere."
            : store.note
        noteLabel.isHidden = (noteLabel.text ?? "").isEmpty

        let ready = store.here != nil
        beginButton.isEnabled = ready
        beginButton.configuration?.attributedTitle = AttributedString(
            ready ? "Begin" : "Looking for you…",
            attributes: AttributeContainer([.font: Theme.body(16, .semibold)]))
        footLabel.text = store.mode == .crossTown
            ? "A fixed line out to a station."
            : "About \(String(format: "%.1f", store.draw.target / 1000)) km to the next stop."
    }
}

/// 気分のチップ。押した状態がひと目で分かるように、墨で塗りつぶす。
final class ChipButton: UIButton {
    var on = false { didSet { restyle() } }
    private let title: String, symbol: String

    init(title: String, symbol: String) {
        self.title = title; self.symbol = symbol
        super.init(frame: .zero)
        restyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func restyle() {
        var c = UIButton.Configuration.plain()
        c.title = title
        c.image = UIImage(systemName: symbol)
        c.imagePadding = 6
        c.contentInsets = .init(top: 10, leading: 12, bottom: 10, trailing: 12)
        c.attributedTitle = AttributedString(title, attributes:
            AttributeContainer([.font: Theme.body(12.5, .medium)]))
        c.baseForegroundColor = on ? .white : Theme.ink
        c.background.backgroundColor = on ? Theme.ink : .clear
        c.background.strokeColor = on ? .clear : Theme.hairline
        c.background.strokeWidth = on ? 0 : 1
        c.background.cornerRadius = 20
        configuration = c
    }
}

/// 歩き方の行。選ばれているほうを墨で塗り、選ばれていないほうを薄くする。
/// ウェブ版では選択が見えず「押せない」と言われたので、ここは強くする。
final class ModeRow: UIButton {
    var on = false { didSet { restyle() } }
    private let title: String, symbol: String, note: String

    init(title: String, symbol: String, note: String) {
        self.title = title; self.symbol = symbol; self.note = note
        super.init(frame: .zero)
        restyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func restyle() {
        var c = UIButton.Configuration.plain()
        c.image = UIImage(systemName: symbol)
        c.imagePadding = 11
        c.imagePlacement = .leading
        c.titleAlignment = .leading
        c.contentInsets = .init(top: 12, leading: 13, bottom: 12, trailing: 13)
        c.attributedTitle = AttributedString(on ? title + "  ✓" : title, attributes:
            AttributeContainer([.font: Theme.body(14, .semibold)]))
        c.attributedSubtitle = AttributedString(note, attributes:
            AttributeContainer([.font: Theme.body(11.5)]))
        c.titlePadding = 2
        c.baseForegroundColor = on ? .white : Theme.ink
        c.background.backgroundColor = on ? Theme.ink : .clear
        c.background.strokeColor = on ? .clear : Theme.hairline
        c.background.strokeWidth = on ? 0 : 1
        c.background.cornerRadius = 12
        configuration = c
        contentHorizontalAlignment = .leading
        alpha = on ? 1 : 0.66
    }
}

#Preview("Sheet") {
    let v = SheetView(store: .preview())
    let host = UIViewController()
    host.view.backgroundColor = Theme.washi2
    v.translatesAutoresizingMaskIntoConstraints = false
    host.view.addSubview(v)
    NSLayoutConstraint.activate([
        v.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 10),
        v.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -10),
        v.bottomAnchor.constraint(equalTo: host.view.bottomAnchor, constant: -10)
    ])
    return host
}
