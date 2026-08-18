import UIKit
import SozoroCore

/// 基準地点を叩いたときの詳細。ウェブ版の detail シートと同じ中身。
/// いまの混み具合、いつ空きはじめるか、そして3層のうちどれが実測かを書く。
final class LandmarkDetailView: UIView {
    var onClose: (() -> Void)?

    init(landmark: Landmark, crowd: Crowd, now: Date, lang: Lang = .en) {
        super.init(frame: .zero)
        func t(_ en: String, _ jp: String) -> String { lang == .ja ? jp : en }
        backgroundColor = Theme.washi
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous

        let spot = landmark.asSpot
        let v = crowd.level(spot, at: now)
        let band = Crowd.band(v)
        let chipText = [
            "quiet": t("Quiet", "空いている"), "mid": t("Busy", "やや混雑"), "busy": t("Packed", "混雑")
        ][band.rawValue]!
        let verdict = [
            "quiet": t("Quiet right now", "いまは空いています"),
            "mid":   t("Fairly busy right now", "いまはやや混んでいます"),
            "busy":  t("Packed right now", "いまは混んでいます")
        ][band.rawValue]!
        let colour = Theme.crowdColour(v)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = Theme.muted
        close.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        // 種類ごとの絵。人影は混み具合で増える。
        let scene = DetailScene(icon: landmark.icon, crowd: v)
        scene.translatesAutoresizingMaskIntoConstraints = false
        scene.heightAnchor.constraint(equalToConstant: 116).isActive = true

        let icon = IconView(landmark.icon, size: 26, colour: Theme.ink)
        let name = makeLabel(lang == .ja ? landmark.ja : landmark.en, Theme.display(21), Theme.ink)
        let ja = makeLabel(lang == .ja ? landmark.en : landmark.ja, Theme.body(11.5), Theme.muted)

        let now100 = makeLabel("\(v)", Theme.mono(34, .semibold), colour)
        let pct = makeLabel("%", Theme.mono(13), colour)
        let chip = pill(chipText, colour)
        let verdictLabel = makeLabel(verdict, Theme.body(13.5, .semibold), Theme.ink)

        // 一日のかたち。いまの時刻に印を置く。
        let chart = CrowdChart(values: crowd.day(spot, on: now),
                               hour: Calendar.current.component(.hour, from: now))
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 62).isActive = true

        let clears = crowd.clearsAt(spot, from: now)
        let head: String, sub: String
        if let c = clears {
            head = t("Clears from about \(c):00", "\(c)時ごろから空きはじめます")
            sub = t("The draw already prefers the quiet side of the map.",
                    "抽選はもともと、空いている側へ寄せてあります。")
        } else if v < 40 {
            head = t("Quiet already", "いまでも空いています")
            sub = t("Good time to be here — or to walk somewhere further out.",
                    "いま来るのに向いています。もっと外へ歩いてもいい。")
        } else {
            head = t("Stays busy for the rest of today", "今日はこのあとも混んだままです")
            sub = t("Walking out is the faster option.", "外へ歩いたほうが早い。")
        }

        let wd = Calendar.current.component(.weekday, from: now)
        let ff = Int((crowd.footfall(at: landmark.coordinate, weekend: wd == 1 || wd == 7) * 100).rounded())
        let meta = makeLabel(t(
            "Three layers. Measured footfall here is \(ff) on a 0–100 scale "
            + "(MLIT people-flow open data, 1 km mesh, Oct 2019). "
            + "The pull of the place itself and the shape of its day are still estimated.",
            "3つの層でできています。ここの人出の実測は0〜100で\(ff)"
            + "（国土交通省 全国の人流オープンデータ、1kmメッシュ、2019年10月）。"
            + "その場所の集客力と一日のかたちは、まだ推定です。"),
            Theme.body(10.5), Theme.muted, lines: 0)

        let top = stack(.horizontal, 11, [icon, stack(.vertical, 1, [name, ja]), UIView(), close], align: .center)
        let numbers = stack(.horizontal, 4, [now100, pct, UIView(), chip], align: .lastBaseline)
        let col = stack(.vertical, 14, [
            top, scene, numbers, verdictLabel, chart,
            stack(.vertical, 3, [makeLabel(head, Theme.body(13, .semibold), Theme.ink),
                                 makeLabel(sub, Theme.body(11.5), Theme.muted, lines: 0)]),
            rule(), meta
        ])
        addSubview(col)
        col.pin(to: self, insets: .init(top: 18, left: 20, bottom: 20, right: 20))
    }
    required init?(coder: NSCoder) { fatalError() }

    private func pill(_ t: String, _ c: UIColor) -> UIView {
        let l = makeLabel(t, Theme.body(11, .semibold), c)
        let dot = UIView()
        dot.backgroundColor = c
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
        let s = stack(.horizontal, 6, [dot, l], align: .center)
        s.isLayoutMarginsRelativeArrangement = true
        s.layoutMargins = .init(top: 5, left: 9, bottom: 5, right: 10)
        s.backgroundColor = c.withAlphaComponent(0.12)
        s.layer.cornerRadius = 10
        return s
    }
    private func rule() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.hairline
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }
}

/// 一日の混み具合。ウェブ版のグラフと同じ形。空いている時間帯に薄い帯を敷く。
final class CrowdChart: UIView {
    private let values: [Int]
    private let hour: Int

    init(values: [Int], hour: Int) {
        self.values = values; self.hour = hour
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard !values.isEmpty, let ctx = UIGraphicsGetCurrentContext() else { return }
        let n = CGFloat(values.count)
        let w = rect.width / n
        let peak = CGFloat(max(values.max() ?? 1, 1))
        for (i, v) in values.enumerated() {
            let h = max(2, rect.height * CGFloat(v) / peak)
            let r = CGRect(x: CGFloat(i) * w + 1, y: rect.height - h, width: w - 2, height: h)
            let c = Theme.crowdColour(v)
            ctx.setFillColor(c.withAlphaComponent(i == hour ? 1 : 0.34).cgColor)
            ctx.fill(r)
        }
        // いまの時刻に細い線を立てる。
        ctx.setStrokeColor(Theme.ink.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(1)
        let x = (CGFloat(hour) + 0.5) * w
        ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: rect.height))
        ctx.strokePath()
    }
}
