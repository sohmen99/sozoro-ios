import UIKit
import SozoroCore

/// 到着の絵。ウェブ版の res-photo と同じ、切り絵のような街並み。
/// 写真が無い地点のほうが多いので、ここは絵で持たせる。
final class ArrivalScene: UIView {
    private let kind: Kind
    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        backgroundColor = Theme.sumi2
        clipsToBounds = true
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ r: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let w = r.width, h = r.height
        // 空。上から下へ、墨から少し明るく。
        let sky = [UIColor(hex: 0x1B1F26).cgColor, UIColor(hex: 0x2A303A).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sky, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        }
        // 月。
        ctx.setFillColor(UIColor(hex: 0x39404B).cgColor)
        ctx.fillEllipse(in: CGRect(x: w * 0.78, y: h * 0.14, width: 34, height: 34))

        // 遠景の街区。
        ctx.setFillColor(UIColor(hex: 0x2C323C).cgColor)
        var x: CGFloat = -10
        var seed = kind == .food ? 7 : 13
        func rnd() -> CGFloat { seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
                                return CGFloat(seed % 1000) / 1000 }
        while x < w + 20 {
            let bw = 26 + rnd() * 44, bh = 40 + rnd() * 62
            ctx.fill(CGRect(x: x, y: h * 0.62 - bh, width: bw, height: bh + h))
            x += bw + 6
        }
        // 手前。行き先の種類で建物のかたちを変える。
        ctx.setFillColor(UIColor(hex: 0x363D48).cgColor)
        if kind == .culture {
            // 屋根の重なり。寺の側面。
            for i in 0..<3 {
                let y = h * 0.70 - CGFloat(i) * 16
                let inset = CGFloat(i) * 16
                let p = UIBezierPath()
                p.move(to: CGPoint(x: w * 0.16 + inset, y: y))
                p.addLine(to: CGPoint(x: w * 0.84 - inset, y: y))
                p.addLine(to: CGPoint(x: w * 0.74 - inset, y: y - 15))
                p.addLine(to: CGPoint(x: w * 0.26 + inset, y: y - 15))
                p.close()
                ctx.addPath(p.cgPath); ctx.fillPath()
            }
            ctx.fill(CGRect(x: w * 0.30, y: h * 0.70, width: w * 0.40, height: h * 0.30))
            ctx.setFillColor(UIColor(hex: 0x8A5148).cgColor)
            ctx.fillEllipse(in: CGRect(x: w * 0.46, y: h * 0.74, width: 26, height: 34))
        } else {
            // 暖簾と提灯。店の側面。
            ctx.fill(CGRect(x: w * 0.18, y: h * 0.60, width: w * 0.64, height: h * 0.40))
            ctx.setFillColor(UIColor(hex: 0x3E4A66).cgColor)
            ctx.fill(CGRect(x: w * 0.18, y: h * 0.60, width: w * 0.64, height: 16))
            ctx.setFillColor(UIColor(hex: 0xD9C79B).cgColor)
            ctx.fill(CGRect(x: w * 0.26, y: h * 0.70, width: w * 0.20, height: h * 0.16))
            ctx.setFillColor(UIColor(hex: 0xA8564A).cgColor)
            ctx.fillEllipse(in: CGRect(x: w * 0.62, y: h * 0.66, width: 24, height: 32))
        }
        // 地面。
        ctx.setFillColor(UIColor(hex: 0x181C22).cgColor)
        ctx.fill(CGRect(x: 0, y: h - 22, width: w, height: 22))
        ctx.setStrokeColor(UIColor(hex: 0x2C323C).cgColor)
        ctx.setLineWidth(2); ctx.setLineDash(phase: 0, lengths: [12, 12])
        ctx.move(to: CGPoint(x: 0, y: h - 11)); ctx.addLine(to: CGPoint(x: w, y: h - 11))
        ctx.strokePath()
    }
}

/// 新しく取れた印を見せる帯。ウェブ版の res-badge。
final class SealBadge: UIView {
    init(symbol: String, title: String, sub: String, fresh: Bool) {
        super.init(frame: .zero)
        backgroundColor = fresh ? Theme.quietDk.withAlphaComponent(0.14) : Theme.sumi2
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        if fresh {
            layer.borderWidth = 1
            layer.borderColor = Theme.quietDk.withAlphaComponent(0.5).cgColor
        }
        let icon = IconView(symbol, size: 22, colour: fresh ? Theme.quietDk : Theme.mutedDark)
        let seal = UIView()
        seal.addSubview(icon)
        icon.centerXAnchor.constraint(equalTo: seal.centerXAnchor).isActive = true
        icon.centerYAnchor.constraint(equalTo: seal.centerYAnchor).isActive = true
        seal.translatesAutoresizingMaskIntoConstraints = false
        seal.widthAnchor.constraint(equalToConstant: 40).isActive = true
        seal.heightAnchor.constraint(equalToConstant: 40).isActive = true
        seal.backgroundColor = fresh ? Theme.quietDk.withAlphaComponent(0.16) : Theme.sumi3
        seal.layer.cornerRadius = 20

        let t = makeLabel(title, Theme.body(13.5, .semibold), .white)
        let s = makeLabel(sub, Theme.body(11.5), Theme.mutedDark, lines: 0)
        let row = stack(.horizontal, 12, [seal, stack(.vertical, 2, [t, s])], align: .center)
        addSubview(row)
        row.pin(to: self, insets: .init(top: 13, left: 13, bottom: 13, right: 13))

        if fresh {
            transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
            alpha = 0
            UIView.animate(withDuration: 0.42, delay: 0.18, usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0.4) {
                self.transform = .identity; self.alpha = 1
            }
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}
