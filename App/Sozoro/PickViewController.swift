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

        // 色は地点ごとに振る。同じ気分の3枚が同じ顔にならないように。
        thumb.backgroundColor = PickCard.tint(for: spot)
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
            spot.kind == .food ? "fork.knife" : (spot.kind == .green ? "leaf" : "building.columns")))
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

    /// 名前から色相を振る。食は暖色、それ以外は寒色の帯の中で散らす。
    static func tint(for spot: Spot) -> UIColor {
        var h = 5381
        for u in spot.name.unicodeScalars { h = (h &* 33) &+ Int(u.value) }
        let t = CGFloat(abs(h) % 1000) / 1000
        // ぼかしたあとに残るのは色と明暗だけ。種類ごとに帯を分けて、場所ごとに中でずらす。
        let hue: CGFloat
        let sat: CGFloat
        switch spot.kind {
        case .food:    hue = 0.02 + 0.11 * t; sat = 0.42 + 0.16 * t
        case .culture: hue = 0.52 + 0.18 * t; sat = 0.26 + 0.16 * t
        case .green:   hue = 0.24 + 0.12 * t; sat = 0.30 + 0.18 * t
        }
        let bri: CGFloat = 0.34 + 0.20 * CGFloat(abs(h / 7) % 100) / 100
        return UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1)
    }

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

        let eyebrow = UILabel()
        eyebrow.attributedText = Theme.label(store.t("Three ways from here", "ここから 三つ"))
        let title = makeLabel(store.t("Pick one. We still will not say.", "ひとつ選んでください。まだ言いません。"),
                              Theme.display(store.lang == .ja ? 19 : 20), .white, lines: 0)
        let texts = store.teasers(for: store.picks)
        let cards = stack(.vertical, 10, store.picks.enumerated().map { i, s in
            let c = PickCard(spot: s, teaserText: texts[i], metaText: store.meta(s))
            c.addAction(UIAction { [weak self] _ in self?.onChoose?(s) }, for: .touchUpInside)
            return c
        })

        let note = makeLabel(store.note ?? store.t(
            "You find out what it was by standing in front of it.",
            "何だったのかは、その前に立ったときに分かります。"),
                             Theme.body(11), Theme.muted, lines: 0, align: .center)

        let again = quietButton(store.t("Deal again", "引き直す")) { [weak self] in self?.onRedraw?() }
        let back  = quietButton(store.t("Back", "もどる")) { [weak self] in self?.onCancel?() }

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

/// 到着。ここで初めて正体を出す。歩いた数字と、取れた印と、出典。
final class ArrivalViewController: UIViewController {
    private let store: WalkStore
    var onKeep: (() -> Void)?
    var onStop: (() -> Void)?
    var onRewards: (() -> Void)?
    /// 到着したときに新しく取れた印。Root が渡す。
    var freshSeals: [Reward] = []

    init(store: WalkStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi
        let ja = store.lang == .ja

        let eyebrow = UILabel()
        eyebrow.attributedText = Theme.label(ja ? "とうちゃく" : "You made it")
        let head = makeLabel(ja ? "これでした。" : "This is what it was.",
                             Theme.display(ja ? 24 : 26), .white, lines: 0)

        // 絵。写真の無い地点のほうが多いので、ここは描く。
        let scene = ArrivalScene(kind: store.destination?.kind ?? .culture)
        scene.translatesAutoresizingMaskIntoConstraints = false
        scene.heightAnchor.constraint(equalToConstant: 140).isActive = true

        let name = makeLabel(store.destination.map(store.name) ?? "—",
                             Theme.display(21), .white, lines: 0)
        let cat = makeLabel(store.destination.map(store.category) ?? "",
                            Theme.mono(10.5), Theme.mutedDark)
        let card = stack(.vertical, 10, [scene, stack(.vertical, 4, [name, cat])])
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = .init(top: 12, left: 12, bottom: 14, right: 12)
        card.backgroundColor = Theme.sumi2
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous

        // 歩いた数字。分散は「出発地よりどれだけ空いた場所へ出たか」。
        let walked = store.origin.flatMap { o in
            store.destination.map { Geo.distance(o, $0.coordinate) * store.draw.config.detour }
        } ?? 0
        let quieter = store.dispersion
        let stats = stack(.horizontal, 0, [
            metric(String(format: "%.1f", walked / 1000), "km", ja ? "あるいた" : "walked"),
            metric("\(store.stops.count)", "", ja ? "たちよった" : "stops"),
            metric("\(quieter)", "%", ja ? "すいてた" : "quieter", tint: Theme.quietDk)
        ])
        stats.distribution = .fillEqually

        var rows: [UIView] = [stack(.vertical, 4, [eyebrow, head]), card, stats]

        // 取れた印。新しいものがあれば、そこだけ目立たせる。
        let earned = WalkLog.shared.earned
        if let f = freshSeals.first {
            rows.append(SealBadge(symbol: rewardIcon(f.id), title: f.title(store.lang),
                                  sub: (ja ? "あたらしい印 — " : "New — ") + f.condition(store.lang),
                                  fresh: true))
        } else {
            rows.append(SealBadge(symbol: "i-seal",
                                  title: ja ? "印は \(earned.count) / \(Reward.all.count)"
                                            : "\(earned.count) of \(Reward.all.count) marks",
                                  sub: ja ? "\(WalkLog.shared.walks.count)回目のさんぽ"
                                          : "Walk \(WalkLog.shared.walks.count)",
                                  fresh: false))
        }

        rows.append(button(ja ? "地図で見る" : "See it on the map", quiet: true) { [weak self] in
            guard let d = self?.store.destination else { return }
            let u = "http://maps.apple.com/?ll=\(d.coordinate.lat),\(d.coordinate.lon)&q="
                  + (d.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            URL(string: u).map { UIApplication.shared.open($0) }
        })
        rows.append(button(ja ? "この さんぽを 知らせる" : "Share where you ended up", quiet: true) {
            [weak self] in self?.share()
        })
        rows.append(keepButton())
        rows.append(button(ja ? "あつめた印" : "Marks you have", quiet: true, small: true) {
            [weak self] in self?.onRewards?()
        })
        rows.append(button(ja ? "ここで終える" : "Stop here", quiet: true, small: true) {
            [weak self] in self?.onStop?()
        })
        rows.append(makeLabel(source(), Theme.body(9.5), Theme.ink2, lines: 0))

        let scroll = UIScrollView()
        let col = stack(.vertical, 14, rows)
        scroll.addSubview(col)
        col.pin(to: scroll, insets: .init(top: 24, left: 22, bottom: 40, right: 22))
        col.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -44).isActive = true
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func metric(_ v: String, _ unit: String, _ key: String,
                        tint: UIColor = .white) -> UIView {
        let value = makeLabel(v, Theme.mono(23, .semibold), tint, align: .center)
        let u = makeLabel(unit, Theme.mono(11), Theme.mutedDark)
        let k = UILabel(); k.attributedText = Theme.label(key); k.textAlignment = .center
        let top = stack(.horizontal, 2, [value, u], align: .lastBaseline)
        top.alignment = .lastBaseline
        let wrap = UIView(); wrap.addSubview(top)
        top.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            top.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            top.topAnchor.constraint(equalTo: wrap.topAnchor),
            top.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])
        return stack(.vertical, 4, [wrap, k])
    }

    private func keepButton() -> UIButton {
        let ja = store.lang == .ja
        let title: String
        if let c = store.course, c.remaining > 0 {
            title = ja ? "つぎへ" : "Next stop"
        } else if store.course != nil {
            title = ja ? "もう一度あるく" : "Walk again"
        } else {
            title = ja ? "もう一か所" : "Keep going"
        }
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Theme.quietDk
        cfg.baseForegroundColor = Theme.sumi
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 13, leading: 16, bottom: 13, trailing: 16)
        cfg.attributedTitle = AttributedString(title, attributes:
            AttributeContainer([.font: Theme.body(16, .semibold)]))
        let b = UIButton(type: .system)
        b.configuration = cfg
        b.addAction(UIAction { [weak self] _ in self?.onKeep?() }, for: .touchUpInside)
        return b
    }

    private func button(_ t: String, quiet: Bool, small: Bool = false,
                        _ act: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        var c = UIButton.Configuration.plain()
        c.attributedTitle = AttributedString(t, attributes:
            AttributeContainer([.font: Theme.body(small ? 12.5 : 14, .medium)]))
        c.baseForegroundColor = small ? Theme.mutedDark : .white
        if !small {
            c.background.strokeColor = UIColor.white.withAlphaComponent(0.16)
            c.background.strokeWidth = 1
            c.background.cornerRadius = 10
        }
        c.contentInsets = .init(top: 11, leading: 14, bottom: 11, trailing: 14)
        b.configuration = c
        b.addAction(UIAction { _ in act() }, for: .touchUpInside)
        return b
    }

    private func rewardIcon(_ id: String) -> String {
        ["first": "i-foot", "three": "i-route", "ten": "i-seal", "cross": "i-bridge",
         "areas3": "i-map", "areas5": "i-compass", "ri": "i-mount", "far": "i-flag",
         "against": "i-wind", "ebb": "i-ripple", "blind": "i-eyeoff", "dawn": "i-sunrise",
         "dusk": "i-moon", "both": "i-grid", "regular": "i-calendar"][id] ?? "i-seal"
    }

    private func source() -> String {
        store.lang == .ja
        ? "出典：台東区オープンデータ（CC-BY表示4.0国際）／本作品の内容について、台東区は一切保証しないものとする。"
          + "荒川区 文化財一覧・観光施設一覧（CC BY）。混雑推定に 国土交通省 全国の人流オープンデータ。"
        : "Sources: Taito City open data (CC-BY 4.0). Taito City makes no warranty as to the content of this work. "
          + "Arakawa City cultural property and visitor site registers (CC BY). "
          + "Crowd estimate uses MLIT nationwide people-flow open data."
    }

    /// 共有。出発地は出さない。自宅であることが多いので。
    private func share() {
        guard let d = store.destination else { return }
        let km = String(format: "%.1f", (store.origin.map {
            Geo.distance($0, d.coordinate) * store.draw.config.detour } ?? 0) / 1000)
        let text = store.lang == .ja
            ? "「\(store.name(d))」に着きました。\(km)km 歩いて、出発地点より \(store.dispersion)% 空いている場所へ。#Tokyosozoro"
            : "Arrived at \(store.name(d)). \(km) km on foot, to somewhere \(store.dispersion)% quieter than where I set off. #Tokyosozoro"
        let img = ShareCard.render(store: store, destination: d)
        let vc = UIActivityViewController(activityItems: [text, img], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        present(vc, animated: true)
    }
}

