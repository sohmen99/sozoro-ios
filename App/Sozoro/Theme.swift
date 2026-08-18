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
    /// 混雑の三段。ウェブ版と同じ切り方。
    static func crowdColour(_ v: Int) -> UIColor {
        v <= 45 ? quiet : (v <= 75 ? mid : busy)
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
