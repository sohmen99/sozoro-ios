import UIKit

/// ウェブ版の色と字をそのまま持ってきたもの。
/// 墨と和紙、藍の差し色、混雑の三段。ここを変えると全部が変わる。
enum Theme {
    static let sumi      = UIColor(hex: 0x14171C)
    static let sumi2     = UIColor(hex: 0x1B1F26)
    static let sumi3     = UIColor(hex: 0x262B34)
    static let ink       = UIColor(hex: 0x20242B)
    static let ink2      = UIColor(hex: 0x454C58)
    static let muted     = UIColor(hex: 0x7B8492)
    static let mutedDark = UIColor(hex: 0x8E96A4)
    static let hairline  = UIColor(hex: 0xDBD8D0)
    static let hairlineDk = UIColor(hex: 0x333944)
    static let washi     = UIColor(hex: 0xF4F2EC)
    static let washi2    = UIColor(hex: 0xEAE7DE)
    static let ai        = UIColor(hex: 0x2A5C8A)
    static let aiLight   = UIColor(hex: 0x7FB3DC)
    static let quiet     = UIColor(hex: 0x0E9578)
    static let mid       = UIColor(hex: 0xCE8E24)
    static let busy      = UIColor(hex: 0xC0392F)
    static let quietDk   = UIColor(hex: 0x35B79A)

    /// 見出しは明朝。ウェブ版と同じ狙いで、和文が入っても崩れない。
    static func display(_ size: CGFloat) -> UIFont {
        let f = UIFont(name: "HiraMinProN-W6", size: size)
            ?? UIFont(name: "Didot-Bold", size: size)
        return f ?? .systemFont(ofSize: size, weight: .semibold)
    }
    static func body(_ size: CGFloat, _ w: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size, weight: w)
    }
    /// 数字はいつも等幅。距離と時間が揺れないように。
    static func mono(_ size: CGFloat, _ w: UIFont.Weight = .regular) -> UIFont {
        .monospacedDigitSystemFont(ofSize: size, weight: w)
    }
    /// 小さい見出し。字間を空けて、うるさくしない。
    static func label(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .kern: 1.5, .foregroundColor: Theme.muted
        ])
    }
    /// 混雑の三段。地点の印とチップに使う。ウェブ版と同じ切り方。
    static func crowdColour(_ v: Int) -> UIColor {
        v <= 45 ? quiet : (v <= 75 ? mid : busy)
    }

    /// ヒートの階調。いちばん混んでいるところが赤紫、空くほど黄色へ抜ける。
    /// 三段のチップ色を流用すると、空いている時間帯に地図が緑に沈む。
    /// ここは「熱」の色として別に持つ。
    private static let heatRamp: [(CGFloat, UIColor)] = [
        (0.00, UIColor(hex: 0xF0DC72)),   // 黄
        (0.35, UIColor(hex: 0xE8A93C)),   // 山吹
        (0.60, UIColor(hex: 0xDD6B2B)),   // 橙
        (0.80, UIColor(hex: 0xC63A2C)),   // 朱
        (1.00, UIColor(hex: 0x8E1E5E))    // 赤紫
    ]

    /// 0〜1 の熱さから色を引く。あいだは線形に混ぜる。
    static func heatColour(_ t: CGFloat) -> UIColor {
        let x = min(1, max(0, t))
        for i in 1..<heatRamp.count {
            let (p1, c1) = heatRamp[i - 1], (p2, c2) = heatRamp[i]
            guard x <= p2 else { continue }
            let k = p2 == p1 ? 0 : (x - p1) / (p2 - p1)
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return UIColor(red: r1 + (r2 - r1) * k, green: g1 + (g2 - g1) * k,
                           blue: b1 + (b2 - b1) * k, alpha: 1)
        }
        return heatRamp.last!.1
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension UIView {
    func pin(to v: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: v.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -insets.bottom)
        ])
    }
}

func stack(_ axis: NSLayoutConstraint.Axis, _ spacing: CGFloat,
           _ views: [UIView], align: UIStackView.Alignment = .fill) -> UIStackView {
    let s = UIStackView(arrangedSubviews: views)
    s.axis = axis; s.spacing = spacing; s.alignment = align
    return s
}

func makeLabel(_ text: String, _ font: UIFont, _ colour: UIColor,
               lines: Int = 0, align: NSTextAlignment = .natural) -> UILabel {
    let l = UILabel()
    l.text = text; l.font = font; l.textColor = colour
    l.numberOfLines = lines; l.textAlignment = align
    return l
}
