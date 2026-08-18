import UIKit
import SwiftUI
import SozoroCore

/// 表紙と地図のあいだに1枚だけ挟む、ボタンの説明。
///
/// 地図の画面はボタンが多い割に、どれも記号だけで出ている。何ができるのかを
/// 一度も言わずに放り込むと、はじめて開いた人は地図を眺めて終わる。
///
/// 実機の画面を撮った画像は貼らない。UIを直すたびに古くなって、
/// 画面と説明が食い違うほうが害が大きいので、**同じ記号をその場で描く**。
@MainActor
final class GuideViewController: UIViewController {
    private let store: WalkStore
    var onContinue: (() -> Void)?

    init(store: WalkStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        let eyebrow = UILabel()
        eyebrow.attributedText = Theme.label("What the buttons do")
        let head = makeLabel("The map screen, briefly", Theme.display(27), .white, lines: 0)
        let sub = makeLabel(
            "Everything you need is on one screen. Here is what each control is for.",
            Theme.body(13), Theme.mutedDark, lines: 0)

        var rows: [UIView] = [stack(.vertical, 6, [eyebrow, head, sub]), rule()]

        rows.append(section("ALONG THE TOP"))
        rows.append(row(symbol: "chevron.left", round: true, title: "Back to the cover",
                        body: "The opening screen. Nothing is lost."))
        rows.append(row(symbol: "seal", round: true, title: "Marks you have",
                        body: "Fifteen marks for walking, and the record of every walk."))
        rows.append(row(symbol: "wand.and.stars", round: true, title: "Simulation mode",
                        body: "Place yourself anywhere and set any hour, without going outside. "
                            + "Tap the map to stand there; the crowd estimate follows the clock you set."))

        rows.append(section("ON THE MAP"))
        rows.append(row(icon: "i-temple", title: "A marker with a coloured dot",
                        body: "Twenty-one places we use to read the crowd. "
                            + "The dot is our estimate: green quiet, red busy, purple packed. "
                            + "Tap one for the day's shape and when it should clear."))
        rows.append(row(symbol: "circle.fill", tint: Theme.mid, title: "The red dot is you",
                        body: "Your position never leaves the phone."))

        rows.append(section("THE CARD AT THE BOTTOM"))
        rows.append(row(symbol: "minus", title: "Drag it up and down",
                        body: "Pull it down to see more of the map. The legend and scale come with it."))
        rows.append(row(symbol: "fork.knife", title: "Food · Culture",
                        body: "What you are in the mood for. Pick either or both. "
                            + "A kind that is closed at this hour cannot be picked."))
        rows.append(row(symbol: "die.face.5", title: "Wander",
                        body: "One stop at a time, about fifteen minutes each. "
                            + "Crowded areas are never drawn. Stop whenever you like."))
        rows.append(row(symbol: "arrow.triangle.turn.up.right.diamond", title: "Cross town",
                        body: "You choose a heading; we draw a fixed line out to a station. "
                            + "Two or three stops on the way, then a train home."))

        rows.append(rule())
        rows.append(makeLabel(
            "Wherever you are sent, the name and the photo stay hidden until you are standing there.",
            Theme.body(12.5), Theme.mutedDark, lines: 0))
        rows.append(Theme.button(.primary, "Show me the map") { [weak self] in self?.onContinue?() })

        let col = stack(.vertical, 16, rows)
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
            col.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            col.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -36),
            col.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 22),
            col.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -22)
        ])
    }

    private func section(_ t: String) -> UIView {
        let l = UILabel()
        l.attributedText = Theme.label(t)
        return l
    }

    private func rule() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.hairlineDk
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    /// 説明の一行。記号は地図で使っているものと同じものを描く。
    private func row(symbol: String? = nil, icon: String? = nil, round: Bool = false,
                     tint: UIColor? = nil, title: String, body: String) -> UIView {
        let badge = UIView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 44).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 44).isActive = true
        badge.layer.cornerRadius = round ? 22 : 12
        badge.layer.cornerCurve = .continuous
        // 地図の上のボタンは和紙、シートの中のものは墨。出ている場所と同じ地にする。
        badge.backgroundColor = round ? Theme.washi.withAlphaComponent(0.92) : Theme.sumi3
        badge.layer.borderWidth = round ? 0 : 1
        badge.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor

        let mark: UIView
        if let icon {
            mark = IconView(icon, size: 22, colour: round ? Theme.ink : .white)
        } else {
            let v = UIImageView(image: UIImage(systemName: symbol ?? "circle"))
            v.tintColor = tint ?? (round ? Theme.ink : .white)
            v.contentMode = .scaleAspectFit
            mark = v
        }
        badge.addSubview(mark)
        mark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mark.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            mark.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            mark.widthAnchor.constraint(equalToConstant: 22),
            mark.heightAnchor.constraint(equalToConstant: 22)
        ])

        let t = makeLabel(title, Theme.body(14.5, .semibold), .white, lines: 0)
        let b = makeLabel(body, Theme.body(12.5), Theme.mutedDark, lines: 0)
        let text = stack(.vertical, 3, [t, b])
        return stack(.horizontal, 13, [badge, text], align: .top)
    }
}

#Preview("Guide") { GuideViewController(store: .preview()) }
