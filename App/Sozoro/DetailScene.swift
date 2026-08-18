import UIKit
import SozoroCore

/// 基準地点の絵。アイコンの種類ごとに描き分ける。
/// ウェブ版は浅草寺の一枚絵だったが、21地点あるので種類ぶん用意する。
final class DetailScene: UIView {
    private let icon: String
    private let crowd: Int

    init(icon: String, crowd: Int) {
        self.icon = icon; self.crowd = crowd
        super.init(frame: .zero)
        backgroundColor = UIColor(hex: 0xDCD8CE)
        clipsToBounds = true
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ r: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        let w = r.width, h = r.height
        c.setFillColor(UIColor(hex: 0xDCD8CE).cgColor)
        c.fill(r)
        c.setFillColor(UIColor(hex: 0xCFCABF).cgColor)
        c.fillEllipse(in: CGRect(x: w * 0.80, y: h * 0.10, width: h * 0.34, height: h * 0.34))

        let far = UIColor(hex: 0x9BA0AB), near = UIColor(hex: 0x5C6270), dark = UIColor(hex: 0x494F5C)
        switch icon {
        case "i-pagoda":   pagoda(c, w, h, near, dark)
        case "i-tower":    tower(c, w, h, near, dark)
        case "i-temple":   temple(c, w, h, near, dark)
        case "i-museum":   museum(c, w, h, near, dark)
        case "i-park":     park(c, w, h, near, dark)
        case "i-train":    station(c, w, h, near, dark)
        case "i-craft":    workshop(c, w, h, near, dark)
        case "i-shop":     street(c, w, h, near, dark)
        default:           street(c, w, h, near, dark)
        }
        crowdFigures(c, w, h, far)
        c.setFillColor(UIColor(hex: 0x181C22).cgColor)
        c.fill(CGRect(x: 0, y: h - h * 0.12, width: w, height: h * 0.12))
        c.setStrokeColor(UIColor(hex: 0x2C323C).cgColor)
        c.setLineWidth(2); c.setLineDash(phase: 0, lengths: [12, 12])
        c.move(to: CGPoint(x: 0, y: h - h * 0.06)); c.addLine(to: CGPoint(x: w, y: h - h * 0.06))
        c.strokePath(); c.setLineDash(phase: 0, lengths: [])
    }

    /// 五重塔と門。浅草寺の側。
    private func pagoda(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(a.cgColor)
        c.fill(CGRect(x: w * 0.16, y: h * 0.40, width: w * 0.09, height: h * 0.48))
        for i in 0..<3 {
            let y = h * (0.40 - CGFloat(i) * 0.10)
            roof(c, cx: w * 0.205, y: y, half: w * 0.09 - CGFloat(i) * w * 0.012, drop: h * 0.08, col: a)
        }
        c.setFillColor(b.cgColor)
        c.fill(CGRect(x: w * 0.44, y: h * 0.50, width: w * 0.40, height: h * 0.38))
        roof(c, cx: w * 0.64, y: h * 0.50, half: w * 0.24, drop: h * 0.12, col: b)
        roof(c, cx: w * 0.64, y: h * 0.38, half: w * 0.21, drop: h * 0.10, col: b)
        c.setFillColor(UIColor(hex: 0x8A5148).cgColor)
        c.fillEllipse(in: CGRect(x: w * 0.59, y: h * 0.58, width: w * 0.10, height: h * 0.20))
    }
    private func tower(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(b.cgColor)
        let p = UIBezierPath()
        p.move(to: CGPoint(x: w * 0.46, y: h * 0.88)); p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.10))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.10)); p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.88))
        p.close(); c.addPath(p.cgPath); c.fillPath()
        c.fill(CGRect(x: w * 0.46, y: h * 0.34, width: w * 0.16, height: h * 0.05))
        c.setFillColor(a.cgColor)
        c.fill(CGRect(x: w * 0.12, y: h * 0.62, width: w * 0.26, height: h * 0.26))
        c.fill(CGRect(x: w * 0.68, y: h * 0.58, width: w * 0.22, height: h * 0.30))
    }
    private func temple(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(b.cgColor)
        c.fill(CGRect(x: w * 0.30, y: h * 0.52, width: w * 0.40, height: h * 0.36))
        roof(c, cx: w * 0.50, y: h * 0.52, half: w * 0.28, drop: h * 0.14, col: b)
        c.setFillColor(UIColor(hex: 0x8A5148).cgColor)
        c.fill(CGRect(x: w * 0.14, y: h * 0.56, width: w * 0.03, height: h * 0.32))
        c.fill(CGRect(x: w * 0.83, y: h * 0.56, width: w * 0.03, height: h * 0.32))
        c.fill(CGRect(x: w * 0.10, y: h * 0.56, width: w * 0.80, height: h * 0.03))
    }
    private func museum(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(b.cgColor)
        c.fill(CGRect(x: w * 0.18, y: h * 0.46, width: w * 0.64, height: h * 0.42))
        let p = UIBezierPath()
        p.move(to: CGPoint(x: w * 0.14, y: h * 0.46)); p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.46))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.28)); p.close()
        c.addPath(p.cgPath); c.fillPath()
        c.setFillColor(a.cgColor)
        for i in 0..<5 {
            c.fill(CGRect(x: w * (0.24 + CGFloat(i) * 0.11), y: h * 0.54, width: w * 0.05, height: h * 0.34))
        }
    }
    private func park(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(UIColor(hex: 0x5E7A55).cgColor)
        for (x, s) in [(0.18, 0.30), (0.44, 0.40), (0.72, 0.26)] {
            let cx = w * CGFloat(x), rr = h * CGFloat(s)
            c.fillEllipse(in: CGRect(x: cx - rr / 2, y: h * 0.42, width: rr, height: rr))
            c.setFillColor(UIColor(hex: 0x6E6152).cgColor)
            c.fill(CGRect(x: cx - w * 0.012, y: h * 0.42 + rr * 0.7, width: w * 0.024, height: h * 0.30))
            c.setFillColor(UIColor(hex: 0x5E7A55).cgColor)
        }
        c.setFillColor(UIColor(hex: 0xC3CDB8).cgColor)
        c.fill(CGRect(x: 0, y: h * 0.80, width: w, height: h * 0.08))
    }
    private func station(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(b.cgColor)
        c.fill(CGRect(x: w * 0.10, y: h * 0.44, width: w * 0.80, height: h * 0.16))
        c.setFillColor(a.cgColor)
        c.fill(CGRect(x: w * 0.14, y: h * 0.60, width: w * 0.30, height: h * 0.28))
        c.fill(CGRect(x: w * 0.56, y: h * 0.60, width: w * 0.30, height: h * 0.28))
        c.setStrokeColor(b.cgColor); c.setLineWidth(2)
        c.move(to: CGPoint(x: 0, y: h * 0.76)); c.addLine(to: CGPoint(x: w, y: h * 0.76))
        c.strokePath()
    }
    private func workshop(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(UIColor(hex: 0xB4A996).cgColor)
        c.fill(CGRect(x: w * 0.12, y: h * 0.40, width: w * 0.76, height: h * 0.48))
        c.setFillColor(UIColor(hex: 0xD9C79B).cgColor)
        c.fill(CGRect(x: w * 0.20, y: h * 0.52, width: w * 0.26, height: h * 0.24))
        c.fill(CGRect(x: w * 0.56, y: h * 0.52, width: w * 0.22, height: h * 0.24))
        c.setFillColor(UIColor(hex: 0x3E4A66).cgColor)
        c.fill(CGRect(x: w * 0.12, y: h * 0.36, width: w * 0.76, height: h * 0.09))
        for i in 0..<4 {
            c.fill(CGRect(x: w * (0.18 + CGFloat(i) * 0.19), y: h * 0.36, width: w * 0.02, height: h * 0.16))
        }
    }
    private func street(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ a: UIColor, _ b: UIColor) {
        c.setFillColor(a.cgColor)
        var x: CGFloat = 0
        var i = 0
        while x < w {
            let bw = w * (0.16 + CGFloat(i % 3) * 0.04)
            let bh = h * (0.30 + CGFloat((i * 7) % 4) * 0.10)
            c.setFillColor((i % 2 == 0 ? a : b).cgColor)
            c.fill(CGRect(x: x, y: h * 0.88 - bh, width: bw - 3, height: bh))
            x += bw; i += 1
        }
        c.setFillColor(UIColor(hex: 0xA8564A).cgColor)
        for k in 0..<3 {
            c.fillEllipse(in: CGRect(x: w * (0.16 + CGFloat(k) * 0.30), y: h * 0.50,
                                     width: w * 0.06, height: h * 0.16))
        }
    }
    private func roof(_ c: CGContext, cx: CGFloat, y: CGFloat, half: CGFloat,
                      drop: CGFloat, col: UIColor) {
        c.setFillColor(col.cgColor)
        let p = UIBezierPath()
        p.move(to: CGPoint(x: cx - half, y: y))
        p.addLine(to: CGPoint(x: cx + half, y: y))
        p.addLine(to: CGPoint(x: cx + half * 0.62, y: y - drop))
        p.addLine(to: CGPoint(x: cx - half * 0.62, y: y - drop))
        p.close()
        c.addPath(p.cgPath); c.fillPath()
    }

    /// 人影。混んでいるほど増える。数字より先に、絵で伝わる。
    private func crowdFigures(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ col: UIColor) {
        let n = max(0, min(14, crowd / 7))
        c.setFillColor(UIColor(hex: 0x3A404B, alpha: 0.85).cgColor)
        var seed = 11
        func rnd() -> CGFloat { seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
                                return CGFloat(seed % 1000) / 1000 }
        for _ in 0..<n {
            let x = rnd() * w, s = h * (0.10 + rnd() * 0.05)
            let y = h * 0.88 - s
            c.fillEllipse(in: CGRect(x: x - s * 0.26, y: y, width: s * 0.52, height: s * 0.52))
            c.fill(CGRect(x: x - s * 0.30, y: y + s * 0.46, width: s * 0.60, height: s * 0.58))
        }
    }
}
