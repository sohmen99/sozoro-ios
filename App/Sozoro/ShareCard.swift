import UIKit
import SozoroCore

/// 共有用の1枚。文字だけだと流れないので絵にする。
/// 出発地は入れない。自宅であることが多いので。
@MainActor
enum ShareCard {
    static func render(store: WalkStore, destination d: Spot) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        let ja = store.lang == .ja
        return UIGraphicsImageRenderer(size: size).image { c in
            let ctx = c.cgContext
            ctx.setFillColor(Theme.sumi.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            func text(_ s: String, _ f: UIFont, _ col: UIColor, _ y: CGFloat,
                      align: NSTextAlignment = .center) {
                let p = NSMutableParagraphStyle(); p.alignment = align
                let a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: col, .paragraphStyle: p]
                let r = CGRect(x: 80, y: y, width: size.width - 160, height: 400)
                (s as NSString).draw(in: r, withAttributes: a)
            }

            text("TOKYO SOZORO", Theme.mono(34, .semibold), Theme.aiLight, 130)
            text(ja ? "行き先を伏せた散歩" : "A walk with the destination hidden",
                 Theme.body(38), Theme.mutedDark, 200)

            let name = store.name(d)
            text(name, Theme.display(name.count > 14 ? 62 : 84), .white, 380)

            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.14).cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: 180, y: 700)); ctx.addLine(to: CGPoint(x: size.width - 180, y: 700))
            ctx.strokePath()

            let km = String(format: "%.1f", (store.origin.map {
                Geo.distance($0, d.coordinate) * store.draw.config.detour } ?? 0) / 1000)
            func stat(_ x: CGFloat, _ big: String, _ small: String) {
                let p = NSMutableParagraphStyle(); p.alignment = .center
                (big as NSString).draw(in: CGRect(x: x - 220, y: 770, width: 440, height: 130),
                    withAttributes: [.font: Theme.mono(96, .semibold),
                                     .foregroundColor: UIColor.white, .paragraphStyle: p])
                (small as NSString).draw(in: CGRect(x: x - 220, y: 900, width: 440, height: 60),
                    withAttributes: [.font: Theme.body(36),
                                     .foregroundColor: Theme.mutedDark, .paragraphStyle: p])
            }
            stat(size.width / 2, km + "km", ja ? "あるいた" : "walked")


            text(ja ? "上野・浅草から、人の少ない側へ歩く"
                    : "Walking away from the crowd, out of Ueno and Asakusa",
                 Theme.body(30), Theme.ink2, 1160)
            text("sohmen99.github.io/tokyo-sozoro", Theme.body(32), Theme.aiLight, 1230)
        }
    }
}
