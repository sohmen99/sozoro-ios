import UIKit
import SozoroCore

/// 表紙。約束だけ示して、抽選の仕組みは明かさない。
final class CoverViewController: UIViewController {
    var onStart: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        let wave = WaveView()
        view.addSubview(wave)
        wave.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wave.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wave.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wave.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            wave.heightAnchor.constraint(equalToConstant: 340)
        ])

        let mark = UILabel()
        mark.attributedText = NSAttributedString(string: "TOKYO SOZORO", attributes: [
            .font: Theme.mono(12, .semibold), .kern: 3.4, .foregroundColor: Theme.aiLight])

        let head = makeLabel("You find out at the end", Theme.display(34), .white, lines: 0)
        let body = makeLabel(
            "A needle and a distance, nothing else. Where it was taking you is something you find out by getting there.",
            Theme.body(14), Theme.mutedDark, lines: 0)

        let facts = stack(.vertical, 12, [
            fact("A bearing and a distance", "No name, no photo, no map line."),
            fact("About 15 minutes at a time", "Stop after one, or keep going."),
            fact("Away from the crowd", "Drawn from the quiet side, using measured footfall.")
        ])

        var c = UIButton.Configuration.filled()
        c.baseBackgroundColor = Theme.quietDk
        c.baseForegroundColor = Theme.sumi
        c.cornerStyle = .large
        c.contentInsets = .init(top: 15, leading: 18, bottom: 15, trailing: 18)
        c.attributedTitle = AttributedString("Begin", attributes:
            AttributeContainer([.font: Theme.body(16, .semibold)]))
        let start = UIButton(type: .system)
        start.configuration = c
        start.addAction(UIAction { [weak self] _ in self?.onStart?() }, for: .touchUpInside)

        let col = stack(.vertical, 22, [mark, stack(.vertical, 12, [head, body]), facts, start])
        view.addSubview(col)
        col.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            col.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func fact(_ t: String, _ s: String) -> UIView {
        let rule = UIView()
        rule.backgroundColor = Theme.hairlineDk
        rule.translatesAutoresizingMaskIntoConstraints = false
        rule.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return stack(.vertical, 6, [
            rule,
            makeLabel(t, Theme.body(13.5, .semibold), .white),
            makeLabel(s, Theme.body(11.5), Theme.muted, lines: 0)
        ])
    }
}

/// 集めた印。歩いた記録と一緒に見せる。
final class RewardsViewController: UIViewController {
    private let log = WalkLog.shared
    var onBack: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        let earned = log.earned
        let walks = log.walks
        let stats = WalkStats(walks)

        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = .white
        back.addAction(UIAction { [weak self] _ in self?.onBack?() }, for: .touchUpInside)

        let head = makeLabel("Marks you have", Theme.display(26), .white)
        let count = makeLabel("\(earned.count) of \(Reward.all.count) · \(stats.count) walks · "
                              + String(format: "%.1f km", stats.totalM / 1000),
                              Theme.mono(12), Theme.mutedDark)

        let grid = UIStackView()
        grid.axis = .vertical; grid.spacing = 8
        for row in stride(from: 0, to: Reward.all.count, by: 3) {
            let r = stack(.horizontal, 8, Reward.all[row..<min(row + 3, Reward.all.count)].map {
                tile($0, got: earned.contains($0.id))
            })
            r.distribution = .fillEqually
            grid.addArrangedSubview(r)
        }

        let scroll = UIScrollView()
        let col = stack(.vertical, 18, [stack(.horizontal, 10, [back, head], align: .center),
                                        count, grid])
        scroll.addSubview(col)
        col.pin(to: scroll, insets: .init(top: 20, left: 20, bottom: 40, right: 20))
        col.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40).isActive = true
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func tile(_ r: Reward, got: Bool) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: r.symbol))
        icon.tintColor = got ? Theme.quietDk : Theme.hairlineDk
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let t = makeLabel(r.title, Theme.body(11.5, .semibold),
                          got ? .white : Theme.muted, lines: 2, align: .center)
        let c = makeLabel(r.condition, Theme.body(9.5),
                          got ? Theme.mutedDark : Theme.hairlineDk, lines: 3, align: .center)
        let box = stack(.vertical, 6, [icon, t, c])
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = .init(top: 13, left: 8, bottom: 13, right: 8)
        box.backgroundColor = got ? Theme.sumi2 : Theme.sumi.withAlphaComponent(0.6)
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = (got ? Theme.quietDk.withAlphaComponent(0.35)
                                     : Theme.hairlineDk).cgColor
        return box
    }
}

/// 表紙の波。ウェブ版の cover-wave と同じ、重ねた弧。
/// 隅田川と、そこへ向かって歩く感じ。文字の後ろに薄く敷く。
final class WaveView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let rows: [(CGFloat, CGFloat, CGFloat)] = [   // y の割合, 振幅, 濃さ
            (0.26, 16, 0.05), (0.40, 20, 0.07), (0.54, 24, 0.09),
            (0.68, 28, 0.11), (0.82, 32, 0.13), (0.95, 36, 0.16)
        ]
        for (fy, amp, alpha) in rows {
            let y = rect.height * fy
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -20, y: y))
            var x: CGFloat = -20
            var up = true
            while x < rect.width + 40 {
                let nx = x + rect.width / 3.2
                p.addQuadCurve(to: CGPoint(x: nx, y: y),
                               controlPoint: CGPoint(x: x + rect.width / 6.4,
                                                     y: y + (up ? -amp : amp)))
                x = nx; up.toggle()
            }
            ctx.setStrokeColor(Theme.aiLight.withAlphaComponent(alpha).cgColor)
            ctx.setLineWidth(1.4)
            ctx.addPath(p.cgPath)
            ctx.strokePath()
        }
    }
}
