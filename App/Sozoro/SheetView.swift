import UIKit
import SozoroCore

/// 地図の下から引き出すシート。混雑を見てから歩き方を決める、という順番はウェブ版のまま。
final class SheetView: UIView {
    private let store: WalkStore
    var onBegin: (() -> Void)?
    /// 畳んだときに見えている高さ。ウェブ版の PEEK_H にあたる。
    static let peekHeight: CGFloat = 128
    private(set) var isOpen = true
    private var travel: CGFloat = 0
    private var dragStart: CGFloat = 0
    var onSlide: ((Bool) -> Void)?

    /// 何色が混んでいるのかと、いまの縮尺。地図の端に置くとシートが滑ったとき
    /// 追いつかないので、カードの見出しに組み込んで一緒に動かす。
    let foot: MapFoot
    // ウェブ版の CATEGORIES と同じ3つ。3つ並ぶので見出しは短くする。
    private let foodChip: ChipButton
    private let cultChip: ChipButton
    private let greenChip: ChipButton
    private let wanderRow: ModeRow
    private let crossRow: ModeRow
    private let beginButton = UIButton(type: .system)
    private let noteLabel = makeLabel("", Theme.body(11.5), Theme.muted, lines: 0)
    private let footLabel = makeLabel("", Theme.body(11.5), Theme.muted, lines: 0)

    init(store: WalkStore) {
        self.store = store
        self.foot = MapFoot(lang: store.lang)
        foodChip  = ChipButton(title: store.t("Food", "たべもの"),  symbol: "fork.knife")
        cultChip  = ChipButton(title: store.t("Culture", "寺社"),   symbol: "building.columns")
        greenChip = ChipButton(title: store.t("Green", "みどり"),   symbol: "leaf")
        wanderRow = ModeRow(title: store.t("Wander", "あてもなく"), symbol: "die.face.5",
            note: store.t("One stop at a time, about 15 minutes each. Stop whenever you like.",
                          "15分ずつ、一か所ずつ。いつでもやめられます。"))
        crossRow = ModeRow(title: store.t("Cross town", "向こうまで"),
            symbol: "arrow.triangle.turn.up.right.diamond",
            note: store.t("A fixed line out to a station. Two or three stops, then a train home.",
                          "駅までの一本道。2〜3か所寄って、電車で帰れます。"))
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
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tappedPeek(_:)))
        peekRow.addGestureRecognizer(tap)
        peekRow.isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 畳んだときに出しっぱなしにする一行。押すと開く。
    private let peekRow = UIView()
    private let peekSummary = makeLabel("", Theme.mono(11.5), Theme.muted)

    /// 指で引く。離したところで開くか閉じるかを決める。
    /// 軽く叩いただけのときは、その場で反転させる。
    @objc private func dragged(_ g: UIPanGestureRecognizer) {
        let dy = g.translation(in: self).y
        switch g.state {
        case .began:
            dragStart = transform.ty
        case .changed:
            var y = dragStart + dy
            // 行き過ぎたぶんは3割だけ効かせて、突き当たりを指に伝える。
            if y < 0 { y = y * 0.3 }
            if y > travel { y = travel + (y - travel) * 0.3 }
            transform = CGAffineTransform(translationX: 0, y: y)
        case .ended, .cancelled:
            let v = g.velocity(in: self).y
            let open = abs(v) > 420 ? (v < 0) : (transform.ty < travel / 2)
            setOpen(open, animated: true)
        default: break
        }
    }

    @objc private func tappedPeek(_ g: UITapGestureRecognizer) {
        setOpen(!isOpen, animated: true)
    }

    func setOpen(_ open: Bool, animated: Bool) {
        isOpen = open
        travel = max(0, bounds.height - Self.peekHeight)
        let t = CGAffineTransform(translationX: 0, y: open ? 0 : travel)
        onSlide?(open)
        guard animated else { transform = t; syncPeek(); return }
        UIView.animate(withDuration: 0.36, delay: 0, usingSpringWithDamping: 0.86,
                       initialSpringVelocity: 0.2, options: [.allowUserInteraction]) {
            self.transform = t
            self.syncPeek()
        }
    }

    private func syncPeek() {
        body.alpha = isOpen ? 1 : 0
        body.isUserInteractionEnabled = isOpen
        peekRow.alpha = isOpen ? 0 : 1
        chevron.transform = CGAffineTransform(rotationAngle: isOpen ? 0 : .pi)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        travel = max(0, bounds.height - Self.peekHeight)
        if !isOpen { transform = CGAffineTransform(translationX: 0, y: travel) }
    }

    private let body = UIStackView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.up"))

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

        let title = makeLabel(store.t("Where should we wander?", "どこへ ぶらつきますか"),
                              Theme.display(21), Theme.ink)
        let sub = makeLabel(store.t(
            "Tell us what you're after. We draw from the quiet side, and keep the spot to ourselves.",
            "気分だけ教えてください。空いている側から引いて、行き先は伏せておきます。"),
                            Theme.body(12.5), Theme.muted, lines: 0)

        let lookLabel = UILabel()
        lookLabel.attributedText = Theme.label(store.t("Looking for", "さがすもの"))
        let chips = stack(.horizontal, 6, [foodChip, cultChip, greenChip])
        chips.distribution = .fillEqually
        foodChip.addAction(UIAction  { [weak self] _ in self?.store.toggle(.food) },    for: .touchUpInside)
        cultChip.addAction(UIAction  { [weak self] _ in self?.store.toggle(.culture) }, for: .touchUpInside)
        greenChip.addAction(UIAction { [weak self] _ in self?.store.toggle(.green) },   for: .touchUpInside)

        let modeLabel = UILabel()
        modeLabel.attributedText = Theme.label(store.t("How you walk", "歩き方"))
        wanderRow.addAction(UIAction { [weak self] _ in self?.store.set(mode: .wander) }, for: .touchUpInside)
        crossRow.addAction(UIAction { [weak self] _ in self?.store.set(mode: .crossTown) }, for: .touchUpInside)

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Theme.ink
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        beginButton.configuration = cfg
        beginButton.addAction(UIAction { [weak self] _ in self?.onBegin?() }, for: .touchUpInside)

        // 畳んだときの一行。いま何を選んでいるかだけ出す。
        chevron.tintColor = Theme.muted
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let peekTitle = makeLabel(store.t("Where to?", "どこへ?"), Theme.body(13, .semibold), Theme.ink)
        let peekStack = stack(.horizontal, 10, [peekTitle, peekSummary, UIView(), chevron], align: .center)
        peekRow.addSubview(peekStack)
        peekStack.pin(to: peekRow, insets: .init(top: 0, left: 0, bottom: 0, right: 0))
        peekRow.translatesAutoresizingMaskIntoConstraints = false
        peekRow.heightAnchor.constraint(equalToConstant: 34).isActive = true

        body.axis = .vertical; body.spacing = 16
        [stack(.vertical, 3, [title, sub]),
         stack(.vertical, 8, [lookLabel, chips]),
         stack(.vertical, 8, [modeLabel, wanderRow, crossRow, noteLabel]),
         beginButton, footLabel].forEach { body.addArrangedSubview($0) }

        let col = stack(.vertical, 12, [gripWrap, foot, peekRow, body])
        addSubview(col)
        col.pin(to: self, insets: .init(top: 12, left: 20, bottom: 46, right: 20))
        syncPeek()
    }

    func refresh() {
        // 閉まっている時間帯は押せなくする。黙って抽選から外すのがいちばん悪い。
        let hour = store.clock()
        for (chip, kind) in [(foodChip, Kind.food), (cultChip, .culture), (greenChip, .green)] {
            let open = kind.isOpen(at: hour)
            chip.isEnabled = open
            chip.alpha = open ? 1 : 0.38
            if !open, store.kinds.contains(kind), store.kinds.count > 1 { store.kinds.remove(kind) }
        }
        foodChip.on  = store.kinds.contains(.food)
        cultChip.on  = store.kinds.contains(.culture)
        greenChip.on = store.kinds.contains(.green)
        wanderRow.on = store.mode == .wander
        crossRow.on = store.mode == .crossTown

        let n = store.wanderCount
        let thin = (n != nil && n! < 3)
        noteLabel.text = thin
            ? store.t("Only \(n!) within 15 minutes of here. Cross town works from anywhere.",
                      "ここから15分の範囲に\(n!)件しかありません。向こうまで抜けるほうはどこからでも動きます。")
            : store.note
        noteLabel.isHidden = (noteLabel.text ?? "").isEmpty

        // 区の外にいると行き先が薄くなるので、押せなくして理由を出す。
        // 黙って押せないボタンが、いちばんよくない。
        let ready = store.here != nil
        let outside = ready && !store.insideWard
        beginButton.isEnabled = ready && !outside
        beginButton.alpha = beginButton.isEnabled ? 1 : 0.42
        beginButton.configuration?.attributedTitle = AttributedString(
            !ready ? store.t("Looking for you…", "現在地をさがしています…")
                   : (outside ? store.t("Too far from the ward", "区から離れすぎています")
                              : store.t("Begin", "はじめる")),
            attributes: AttributeContainer([.font: Theme.body(16, .semibold)]))
        if outside {
            noteLabel.text = store.t(
                "You are outside Taito. The places we can send you to are all back that way.",
                "台東区の外にいます。行き先はみな、そちら側に寄っています。")
            noteLabel.isHidden = false
        }
        peekSummary.text = [
            store.kinds.contains(.food) ? store.t("Food", "たべもの") : nil,
            store.kinds.contains(.culture) ? store.t("Culture", "寺社") : nil,
            store.kinds.contains(.green) ? store.t("Green", "みどり") : nil
        ].compactMap { $0 }.joined(separator: " · ")
            + " / " + (store.mode == .wander ? store.t("Wander", "あてもなく")
                                             : store.t("Cross town", "向こうまで"))
        let km = String(format: "%.1f", store.draw.target / 1000)
        footLabel.text = store.mode == .crossTown
            ? store.t("A fixed line out to a station.", "駅までの一本道です。")
            : store.t("About \(km) km to the next stop.", "次の一か所まで およそ\(km)km。")
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
