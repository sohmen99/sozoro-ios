import UIKit
import SozoroCore

/// ウェブ版の線画アイコンをそのまま描く。24×24 の viewBox を任意の大きさへ。
/// SF Symbols に置き換えると別のアプリの顔になるので、線の太さ（1.7）まで合わせてある。
final class IconView: UIView {
    private let shape = CAShapeLayer()
    var colour: UIColor = Theme.ink { didSet { shape.strokeColor = colour.cgColor } }

    init(_ name: String, size: CGFloat = 22, colour: UIColor = Theme.ink) {
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        self.colour = colour
        backgroundColor = .clear
        shape.fillColor = nil
        shape.strokeColor = colour.cgColor
        shape.lineWidth = 1.7 * (size / 24)
        shape.lineCap = .round
        shape.lineJoin = .round
        layer.addSublayer(shape)
        set(name)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ name: String) {
        guard let s = IconShape.all[name] else { shape.path = nil; return }
        let k = bounds.width / 24
        let p = UIBezierPath()
        for d in s.paths { p.append(SVGPath.parse(d)) }
        for c in s.circles {
            p.append(UIBezierPath(ovalIn: CGRect(x: c.cx - c.r, y: c.cy - c.r,
                                                 width: c.r * 2, height: c.r * 2)))
        }
        for r in s.rects {
            p.append(UIBezierPath(roundedRect: CGRect(x: r.x, y: r.y, width: r.w, height: r.h),
                                  cornerRadius: r.rx))
        }
        for l in s.lines {
            p.move(to: CGPoint(x: l.x1, y: l.y1)); p.addLine(to: CGPoint(x: l.x2, y: l.y2))
        }
        p.apply(CGAffineTransform(scaleX: k, y: k))
        shape.path = p.cgPath
        shape.lineWidth = 1.7 * k
    }
}

/// SVG の d 属性を読む。ウェブ版のアイコンが使う命令だけに絞ってある
/// （M m L l H h V v C c S s A a Z）。
enum SVGPath {
    static func parse(_ d: String) -> UIBezierPath {
        let path = UIBezierPath()
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?
        var cmd: Character = "M"
        var nums: [CGFloat] = []
        var i = d.startIndex

        func flush() {
            guard !nums.isEmpty || cmd == "Z" || cmd == "z" else { return }
            let rel = cmd.isLowercase
            var k = 0
            func n() -> CGFloat { defer { k += 1 }; return k < nums.count ? nums[k] : 0 }
            switch Character(cmd.uppercased()) {
            case "M":
                while k < nums.count {
                    var p = CGPoint(x: n(), y: n())
                    if rel { p = CGPoint(x: cur.x + p.x, y: cur.y + p.y) }
                    if k == 2 { path.move(to: p); start = p } else { path.addLine(to: p) }
                    cur = p
                }
            case "L":
                while k < nums.count {
                    var p = CGPoint(x: n(), y: n())
                    if rel { p = CGPoint(x: cur.x + p.x, y: cur.y + p.y) }
                    path.addLine(to: p); cur = p
                }
            case "H":
                while k < nums.count {
                    let x = n(); cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                    path.addLine(to: cur)
                }
            case "V":
                while k < nums.count {
                    let y = n(); cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                    path.addLine(to: cur)
                }
            case "C":
                while k + 5 < nums.count {
                    var c1 = CGPoint(x: n(), y: n()), c2 = CGPoint(x: n(), y: n()), p = CGPoint(x: n(), y: n())
                    if rel {
                        c1 = CGPoint(x: cur.x + c1.x, y: cur.y + c1.y)
                        c2 = CGPoint(x: cur.x + c2.x, y: cur.y + c2.y)
                        p  = CGPoint(x: cur.x + p.x,  y: cur.y + p.y)
                    }
                    path.addCurve(to: p, controlPoint1: c1, controlPoint2: c2)
                    lastCtrl = c2; cur = p
                }
            case "S":
                while k + 3 < nums.count {
                    var c2 = CGPoint(x: n(), y: n()), p = CGPoint(x: n(), y: n())
                    if rel {
                        c2 = CGPoint(x: cur.x + c2.x, y: cur.y + c2.y)
                        p  = CGPoint(x: cur.x + p.x,  y: cur.y + p.y)
                    }
                    let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                    path.addCurve(to: p, controlPoint1: c1, controlPoint2: c2)
                    lastCtrl = c2; cur = p
                }
            case "A":
                // 円弧。アイコンでは小さな丸みにしか使われないので、円弧で近似する。
                while k + 6 < nums.count {
                    let rx = n(), ry = n(); _ = n(); let large = n(), sweep = n()
                    var p = CGPoint(x: n(), y: n())
                    if rel { p = CGPoint(x: cur.x + p.x, y: cur.y + p.y) }
                    addArc(path, from: cur, to: p, rx: rx, ry: ry,
                           largeArc: large != 0, sweep: sweep != 0)
                    cur = p
                }
            case "Z":
                path.close(); cur = start
            default: break
            }
            nums.removeAll()
        }

        while i < d.endIndex {
            let c = d[i]
            if c.isLetter {
                flush(); cmd = c; i = d.index(after: i); continue
            }
            if c == "-" || c == "." || c.isNumber {
                var j = i
                if d[j] == "-" { j = d.index(after: j) }
                while j < d.endIndex, d[j].isNumber || d[j] == "." { j = d.index(after: j) }
                nums.append(CGFloat(Double(d[i..<j]) ?? 0))
                i = j; continue
            }
            i = d.index(after: i)
        }
        flush()
        return path
    }

    /// 楕円弧。SVG の仕様どおりに中心を出してから描く。
    private static func addArc(_ path: UIBezierPath, from p0: CGPoint, to p1: CGPoint,
                               rx: CGFloat, ry: CGFloat, largeArc: Bool, sweep: Bool) {
        guard rx > 0, ry > 0 else { path.addLine(to: p1); return }
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        var rx = rx, ry = ry
        let l = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
        if l > 1 { rx *= sqrt(l); ry *= sqrt(l) }
        let sign: CGFloat = (largeArc != sweep) ? 1 : -1
        let num = max(0, rx*rx*ry*ry - rx*rx*dy*dy - ry*ry*dx*dx)
        let den = rx*rx*dy*dy + ry*ry*dx*dx
        let co = sign * sqrt(den == 0 ? 0 : num / den)
        let cxp = co * rx * dy / ry, cyp = -co * ry * dx / rx
        let cx = cxp + (p0.x + p1.x) / 2, cy = cyp + (p0.y + p1.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat) -> CGFloat { atan2(uy, ux) }
        let a0 = ang((dx - cxp) / rx, (dy - cyp) / ry)
        let a1 = ang((-dx - cxp) / rx, (-dy - cyp) / ry)
        let t = CGAffineTransform(translationX: cx, y: cy).scaledBy(x: rx, y: ry)
        let arc = UIBezierPath(arcCenter: .zero, radius: 1, startAngle: a0, endAngle: a1, clockwise: sweep)
        arc.apply(t)
        path.append(arc)
    }
}
