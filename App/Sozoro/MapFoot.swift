import UIKit
import MapKit
import SozoroCore

/// 地図の端の凡例と縮尺。ウェブ版の map-foot をそのまま。
/// 何色が混んでいるのかを言わないまま色で塗るのは、読めない図になる。
final class MapFoot: UIView {
    private let scaleLabel = makeLabel("200 m", Theme.mono(10), Theme.ink2)
    private let bar = UIView()
    private var barWidth: NSLayoutConstraint!

    init(lang: Lang) {
        super.init(frame: .zero)
        // シートの見出しの中なので、下敷きは要らない。上下に細い罫だけ引く。
        backgroundColor = .clear
        let rule = UIView()
        rule.backgroundColor = Theme.hairline
        rule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rule)
        NSLayoutConstraint.activate([
            rule.leadingAnchor.constraint(equalTo: leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor),
            rule.bottomAnchor.constraint(equalTo: bottomAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1)
        ])

        let ja = lang == .ja
        let head = UILabel()
        head.attributedText = Theme.label(ja ? "いまの混雑" : "Crowd now")

        let keys = stack(.horizontal, 9, [
            key(Theme.quiet, ja ? "空" : "Quiet"),
            key(Theme.mid,   ja ? "やや混" : "Busy"),
            key(Theme.busy,  ja ? "混雑" : "Packed")
        ])

        bar.backgroundColor = Theme.ink2
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.heightAnchor.constraint(equalToConstant: 2).isActive = true
        barWidth = bar.widthAnchor.constraint(equalToConstant: 64)
        barWidth.isActive = true
        let tickL = tick(), tickR = tick()
        let barRow = UIView()
        [tickL, bar, tickR].forEach { barRow.addSubview($0) }
        tickL.translatesAutoresizingMaskIntoConstraints = false
        tickR.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tickL.leadingAnchor.constraint(equalTo: barRow.leadingAnchor),
            tickL.bottomAnchor.constraint(equalTo: barRow.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: tickL.leadingAnchor),
            bar.bottomAnchor.constraint(equalTo: barRow.bottomAnchor),
            tickR.leadingAnchor.constraint(equalTo: bar.trailingAnchor),
            tickR.bottomAnchor.constraint(equalTo: barRow.bottomAnchor),
            barRow.trailingAnchor.constraint(equalTo: tickR.trailingAnchor),
            barRow.topAnchor.constraint(equalTo: tickL.topAnchor)
        ])

        let scale = stack(.vertical, 4, [scaleLabel, barRow], align: .trailing)
        let row = stack(.horizontal, 12, [stack(.vertical, 6, [head, keys]), UIView(), scale],
                        align: .bottom)
        scale.setContentHuggingPriority(.required, for: .horizontal)
        scale.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(row)
        row.pin(to: self, insets: .init(top: 2, left: 0, bottom: 10, right: 0))
    }
    required init?(coder: NSCoder) { fatalError() }

    private func key(_ c: UIColor, _ t: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = c
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        let l = makeLabel(t, Theme.body(10.5), Theme.ink2)
        l.numberOfLines = 1
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stack(.horizontal, 5, [dot, l], align: .center)
    }
    private func tick() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.ink2
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 6).isActive = true
        return v
    }

    /// 地図の縮尺に合わせて棒の長さと数字を決める。
    /// 100/200/500/1000/2000 の刻みはウェブ版と同じ。
    func update(from map: MKMapView) {
        let metresPerPoint = map.visibleMapRect.size.width
            / Double(map.bounds.width) / MKMapPointsPerMeterAtLatitude(map.centerCoordinate.latitude)
        let target = 78.0 * metresPerPoint
        let steps: [Double] = [50, 100, 200, 500, 1000, 2000, 5000]
        let m = steps.min(by: { abs($0 - target) < abs($1 - target) }) ?? 200
        barWidth.constant = CGFloat(m / metresPerPoint)
        scaleLabel.text = m >= 1000 ? "\(Int(m / 1000)) km" : "\(Int(m)) m"
    }
}
