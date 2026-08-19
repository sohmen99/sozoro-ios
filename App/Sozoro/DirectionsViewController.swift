import UIKit
import SwiftUI
import SozoroCore

/// 片道モードで、どの方角へ抜けるかを決める画面。ウェブ版の #dir をそのまま。
///
/// 黙って一本引いてしまうと、選べるはずのものを選ばせていないことになる。
/// 方角・駅・分・区間だけ見せて、**途中に寄る場所は伏せたまま**にする。
/// 決められないときのために「まかせる」も置く。
@MainActor
final class DirectionsViewController: UIViewController {
    private let store: WalkStore
    var onStart: (() -> Void)?
    var onCancel: (() -> Void)?

    init(store: WalkStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        let head = makeLabel(store.t("Which way out?", "どっちへ抜けますか"),
                             Theme.display(26), .white, lines: 0)
        let sub = makeLabel(
            store.t("Choose a heading, or let it be chosen for you. The stops along the way stay hidden.",
                    "方角を選ぶか、まかせてください。途中に寄る場所は伏せたままです。"),
            Theme.body(13), Theme.mutedDark, lines: 0)

        let opts = store.directionOptions
        var rows: [UIView] = [stack(.vertical, 6, [head, sub])]
        for o in opts { rows.append(row(for: o)) }

        // まかせる。押した時点で決まるので、あとから「まだ続けるか」は聞かない。
        let any = Theme.button(.secondary, store.t("Let it choose", "まかせる")) { [weak self] in
            guard let self, let h = self.store.here else { return }
            self.store.startCourse(from: h)
            self.onStart?()
        }
        let cancel = Theme.button(.tertiary, store.t("Back to the map", "地図にもどる"),
                                  small: true) { [weak self] in self?.onCancel?() }
        // 選ぶものと、締めの操作のあいだに間を置く。並びで意味が分かるように。
        let gap = UIView()
        gap.translatesAutoresizingMaskIntoConstraints = false
        gap.heightAnchor.constraint(equalToConstant: 6).isActive = true
        rows.append(contentsOf: [gap, any, cancel])

        let col = stack(.vertical, 12, rows)
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(col)
        col.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            col.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 22),
            col.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -34),
            col.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 22),
            col.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -22)
        ])
    }

    /// 一方角ぶん。ウェブ版と同じで、方角・駅名・分・区間数だけ。
    private func row(for o: Route.Option) -> UIView {
        // 区間数は式から出さず、実際に組んだコースから数える。
        // 中間点に寄り道が見つからないと、約束した数と食い違う。
        let legs = max(1, store.route.build(from: store.here ?? o.station.coordinate, to: o).stops.count)
        let ja = store.lang == .ja
        let name = store.data.displayName(o.station, japanese: ja)
        let b = UIButton(type: .system)
        var c = UIButton.Configuration.plain()
        c.contentInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        c.background.cornerRadius = 16
        c.background.backgroundColor = Theme.sumi2
        c.background.strokeColor = UIColor.white.withAlphaComponent(0.18)
        c.background.strokeWidth = 1
        b.configuration = c

        // 方角の記号。押す前に、どっちへ向くのかが絵で分かるように。
        let arrow = UIImageView(image: UIImage(systemName: "arrow.up",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)))
        arrow.tintColor = Theme.quietDk
        arrow.transform = CGAffineTransform(rotationAngle: CGFloat(o.bearing) * .pi / 180)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.widthAnchor.constraint(equalToConstant: 26).isActive = true
        arrow.contentMode = .center

        let dir = makeLabel(ja ? o.direction.ja : o.direction.en, Theme.body(16, .semibold), .white)
        let st = makeLabel(name, Theme.body(13), .white.withAlphaComponent(0.72))
        let m = makeLabel(ja ? "\(o.minutes)分・\(legs)区間"
                             : "\(o.minutes) min · \(legs) \(legs == 1 ? "leg" : "legs")",
                          Theme.mono(11.5), Theme.mutedDark)
        let text = stack(.vertical, 3, [dir, st, m])
        let chev = UIImageView(image: UIImage(systemName: "chevron.right"))
        chev.tintColor = Theme.mutedDark
        chev.setContentHuggingPriority(.required, for: .horizontal)
        let col = stack(.horizontal, 12, [arrow, text, UIView(), chev], align: .center)
        col.isUserInteractionEnabled = false
        b.addSubview(col)
        col.pin(to: b, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        b.addAction(UIAction { [weak self] _ in
            guard let self, let h = self.store.here else { return }
            self.store.startCourse(from: h, with: o)
            self.onStart?()
        }, for: .touchUpInside)
        return b
    }

    private func ghost(_ title: String, _ act: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        var c = UIButton.Configuration.plain()
        c.attributedTitle = AttributedString(
            title, attributes: AttributeContainer([.font: Theme.body(14, .semibold)]))
        c.baseForegroundColor = Theme.mutedDark
        c.contentInsets = .init(top: 13, leading: 16, bottom: 13, trailing: 16)
        c.background.cornerRadius = 16
        c.background.strokeColor = Theme.hairlineDk
        c.background.strokeWidth = 1
        b.configuration = c
        b.addAction(UIAction { _ in act() }, for: .touchUpInside)
        return b
    }
}

/// 一言だけの知らせ。押せないものを黙って押させないための口。
/// ウェブ版の toast にあたる。消えるまで2.6秒。
@MainActor
enum Toast {
    static func show(_ text: String, over host: UIView) {
        host.subviews.filter { $0.tag == 8801 }.forEach { $0.removeFromSuperview() }
        let card = UIView()
        card.tag = 8801
        card.backgroundColor = Theme.sumi.withAlphaComponent(0.94)
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.hairlineDk.cgColor
        card.alpha = 0

        let l = makeLabel(text, Theme.body(13), .white, lines: 0)
        card.addSubview(l)
        l.pin(to: card, insets: .init(top: 11, left: 14, bottom: 11, right: 14))

        host.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 18),
            card.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -18),
            card.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            card.topAnchor.constraint(equalTo: host.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
        card.transform = CGAffineTransform(translationX: 0, y: -8)
        UIView.animate(withDuration: 0.22) {
            card.alpha = 1; card.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 2.6, options: []) {
            card.alpha = 0; card.transform = CGAffineTransform(translationX: 0, y: -8)
        } completion: { _ in card.removeFromSuperview() }
    }
}

#Preview("Directions")   { DirectionsViewController(store: .preview()) }
#Preview("方角をえらぶ") { DirectionsViewController(store: .preview(lang: .ja)) }
