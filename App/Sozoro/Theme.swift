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
    /// 羅針盤の重り側。ウェブ版の #3B434F。
    static let needleTail = UIColor(hex: 0x3B434F)
    static let hairline  = UIColor(hex: 0xDBD8D0)
    static let hairlineDk = UIColor(hex: 0x333944)
    static let washi     = UIColor(hex: 0xF4F2EC)
    static let washi2    = UIColor(hex: 0xEAE7DE)
    static let ai        = UIColor(hex: 0x2A5C8A)
    static let aiLight   = UIColor(hex: 0x7FB3DC)
    static let quiet     = UIColor(hex: 0x0E9578)
    static let mid       = UIColor(hex: 0xC0392F)
    static let busy      = UIColor(hex: 0x7B2D8E)
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
    /// ボタンは3階層しかない。画面ごとに手で書くと、押せるのか押せないのか
    /// 分からない灰色が湧くので、ここに集める。
    ///
    ///   primary   … いま押すもの。緑のベタ。1画面に1つだけ
    ///   secondary … 押せるもの。面と枠があり、地の色に沈まない
    ///   tertiary  … 下がる・やめる。控えめだが **必ず枠がある**
    ///
    /// 「押せるが今は勧めない」を灰色のベタで表さない。灰色のベタは無効の意味で、
    /// 押せるものに使うと、押していいのか分からなくなる。
    enum Rank { case primary, secondary, tertiary }

    static func buttonConfig(_ rank: Rank, _ title: String, small: Bool = false)
        -> UIButton.Configuration {
        var c = UIButton.Configuration.filled()
        let size: CGFloat = small ? 13.5 : 16
        switch rank {
        case .primary:
            c.baseBackgroundColor = quietDk
            c.baseForegroundColor = sumi
        case .secondary:
            c.baseBackgroundColor = sumi3
            c.baseForegroundColor = .white
            c.background.strokeColor = UIColor.white.withAlphaComponent(0.22)
            c.background.strokeWidth = 1
        case .tertiary:
            c.baseBackgroundColor = .clear
            c.baseForegroundColor = mutedDark
            c.background.strokeColor = hairlineDk
            c.background.strokeWidth = 1
        }
        c.cornerStyle = .large
        c.contentInsets = .init(top: small ? 11 : 14, leading: 16,
                                bottom: small ? 11 : 14, trailing: 16)
        c.attributedTitle = AttributedString(title, attributes:
            AttributeContainer([.font: body(size, .semibold)]))
        return c
    }

    /// 3階層のボタンを1本作る。
    @MainActor
    static func button(_ rank: Rank, _ title: String, small: Bool = false,
                       _ act: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.configuration = buttonConfig(rank, title, small: small)
        b.addAction(UIAction { _ in act() }, for: .touchUpInside)
        return b
    }

    /// 取り消せない行動の確認。散歩を終える・区間をやめる。
    @MainActor
    static func confirm(on vc: UIViewController, title: String, message: String,
                        keep: String, go: String, _ act: @escaping () -> Void) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: keep, style: .cancel))
        a.addAction(UIAlertAction(title: go, style: .destructive) { _ in act() })
        vc.present(a, animated: true)
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
        v < 40 ? quiet : (v < 70 ? mid : busy)
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
