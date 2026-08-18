import UIKit
import SozoroCore

/// コンパスの文字盤。針は片側だけ。追う先を取り違えないように、反対の端は短い重りにする。
/// 角度は足しこむので、北をまたいでも逆回りしない。
/// コンパスの文字盤。ウェブ版の 300×300 の図をそのまま起こしてある。
/// 外輪・内輪・点線の輪・四方の目盛りと文字・進捗の輪、そして片側だけの針。
final class CompassDial: UIView {
    private let rings = CAShapeLayer()
    private let ticks = CAShapeLayer()
    private let dashed = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let needle = CALayer()
    private var marks: [UILabel] = []
    private var shown: Double = 0
    /// ウェブ版の図と同じ座標系で組んで、最後に縮める。ズレの元を作らない。
    private static let box: CGFloat = 300

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        [rings, dashed, ticks, progress].forEach { layer.addSublayer($0) }
        layer.addSublayer(needle)
        for t in ["N", "E", "S", "W"] {
            let l = makeLabel(t, Theme.mono(11), Theme.mutedDark, align: .center)
            addSubview(l); marks.append(l)
        }
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let c = CGPoint(x: 150, y: 150)
        // 外輪 142 / 内輪 112。ウェブ版と同じ半径。
        let r = UIBezierPath(arcCenter: c, radius: 142, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        r.append(UIBezierPath(arcCenter: c, radius: 112, startAngle: 0, endAngle: .pi * 2, clockwise: true))
        rings.path = r.cgPath
        rings.fillColor = nil; rings.strokeColor = Theme.hairlineDk.cgColor; rings.lineWidth = 1

        let d = UIBezierPath(arcCenter: c, radius: 86, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        dashed.path = d.cgPath
        dashed.fillColor = nil; dashed.strokeColor = Theme.sumi3.cgColor
        dashed.lineWidth = 1; dashed.lineDashPattern = [1, 7]; dashed.lineCap = .round

        // 四方の目盛りと、斜め45度の短い印。
        let t = UIBezierPath()
        t.move(to: CGPoint(x: 150, y: 8));   t.addLine(to: CGPoint(x: 150, y: 22))
        t.move(to: CGPoint(x: 150, y: 278)); t.addLine(to: CGPoint(x: 150, y: 292))
        t.move(to: CGPoint(x: 8, y: 150));   t.addLine(to: CGPoint(x: 22, y: 150))
        t.move(to: CGPoint(x: 278, y: 150)); t.addLine(to: CGPoint(x: 292, y: 150))
        t.move(to: CGPoint(x: 50, y: 50));   t.addLine(to: CGPoint(x: 59, y: 59))
        t.move(to: CGPoint(x: 250, y: 50));  t.addLine(to: CGPoint(x: 241, y: 59))
        t.move(to: CGPoint(x: 50, y: 250));  t.addLine(to: CGPoint(x: 59, y: 241))
        t.move(to: CGPoint(x: 250, y: 250)); t.addLine(to: CGPoint(x: 241, y: 241))
        ticks.path = t.cgPath
        ticks.fillColor = nil; ticks.strokeColor = Theme.ink2.cgColor
        ticks.lineWidth = 1; ticks.lineCap = .round

        progress.path = UIBezierPath(arcCenter: c, radius: 142, startAngle: -.pi / 2,
                                     endAngle: .pi * 1.5, clockwise: true).cgPath
        progress.fillColor = nil; progress.strokeColor = Theme.quietDk.cgColor
        progress.lineWidth = 2; progress.lineCap = .round; progress.strokeEnd = 0

        buildNeedle()
    }

    /// 針。ウェブ版と同じ長さで、行き先側だけを矢にする。
    private func buildNeedle() {
        // 重り側。ウェブ版は 150→196 の線と、172〜196 の小さな三角。
        let tail = CAShapeLayer()
        let tp = UIBezierPath()
        tp.move(to: CGPoint(x: 0, y: 22)); tp.addLine(to: CGPoint(x: -8, y: 46))
        tp.addLine(to: CGPoint(x: 8, y: 46)); tp.close()
        tail.path = tp.cgPath
        tail.fillColor = Theme.needleTail.cgColor

        let tailShaft = CAShapeLayer()
        tailShaft.path = UIBezierPath(roundedRect: CGRect(x: -1.5, y: -1.5, width: 3, height: 47.5),
                                      cornerRadius: 1.5).cgPath
        tailShaft.fillColor = Theme.needleTail.cgColor

        let shaft = CAShapeLayer()
        shaft.path = UIBezierPath(roundedRect: CGRect(x: -2.5, y: -88, width: 5, height: 88),
                                  cornerRadius: 2.5).cgPath
        shaft.fillColor = Theme.quietDk.cgColor

        let head = CAShapeLayer()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 0, y: -128)); p.addLine(to: CGPoint(x: 17, y: -84))
        p.addLine(to: CGPoint(x: 0, y: -92)); p.addLine(to: CGPoint(x: -17, y: -84))
        p.close()
        head.path = p.cgPath; head.fillColor = Theme.quietDk.cgColor

        let bead = CAShapeLayer()
        bead.path = UIBezierPath(ovalIn: CGRect(x: -4, y: -68, width: 8, height: 8)).cgPath
        bead.fillColor = Theme.sumi.cgColor
        bead.strokeColor = Theme.quietDk.cgColor; bead.lineWidth = 2

        let hub = CAShapeLayer()
        hub.path = UIBezierPath(ovalIn: CGRect(x: -4, y: -4, width: 8, height: 8)).cgPath
        hub.fillColor = Theme.sumi.cgColor
        hub.strokeColor = Theme.quietDk.cgColor; hub.lineWidth = 2

        // 頭の先の短い印。どちらの端を追うのか、ひと目で分かるように。
        let cap = CAShapeLayer()
        cap.path = UIBezierPath(roundedRect: CGRect(x: -1.5, y: -146, width: 3, height: 11),
                                cornerRadius: 1.5).cgPath
        cap.fillColor = Theme.quietDk.cgColor

        [tailShaft, tail, shaft, head, bead, cap, hub].forEach { needle.addSublayer($0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 300 の座標系で組んだものを、いまの大きさに合わせて縮める。
        //
        // frame で当ててはいけない。frame は bounds・position・transform から
        // 逆算される値なので、すでに縮尺が掛かっている層に frame を代入すると、
        // その縮尺のぶん bounds が小さく取り直される。呼ばれるたびに縮む。
        // 距離の表示が変わるだけでここが走るので、歩き始めると盤がずれていく。
        // bounds と position と縮尺を別々に置けば、何度呼ばれても同じ結果になる。
        let side = min(bounds.width, bounds.height)
        let k = side / Self.box
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let square = CGRect(x: 0, y: 0, width: Self.box, height: Self.box)
        for l in [rings, dashed, ticks, progress] {
            l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            l.bounds = square
            l.position = c
            l.transform = CATransform3DMakeScale(k, k, 1)
        }
        // 針は中心を軸に回すので、位置だけ合わせて拡大は別に持つ。
        needle.position = c
        needle.bounds = .zero
        applyNeedleTransform()

        let rr = 142 * k
        let places: [(CGFloat, CGFloat)] = [(0, -rr - 2), (rr + 2, 0), (0, rr + 2), (-rr - 2, 0)]
        for (i, l) in marks.enumerated() {
            l.sizeToFit()
            l.center = CGPoint(x: c.x + places[i].0, y: c.y + places[i].1)
        }
    }

    private var scale: CGFloat { min(bounds.width, bounds.height) / Self.box }

    private func applyNeedleTransform() {
        let k = scale
        needle.transform = CATransform3DConcat(
            CATransform3DMakeScale(k, k, 1),
            CATransform3DMakeRotation(CGFloat(shown * .pi / 180), 0, 0, 1))
    }

    /// 差を -180〜180 に畳んでから足す。359°から1°へ動くとき一周しない。
    func point(to rotation: Double, progressValue: Double?) {
        let delta = ((rotation - shown).truncatingRemainder(dividingBy: 360) + 540)
                        .truncatingRemainder(dividingBy: 360) - 180
        shown += delta
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        applyNeedleTransform()
        progress.strokeEnd = CGFloat(progressValue ?? 0)
        CATransaction.commit()
    }
}

/// 歩いている画面。方角と残り距離だけ。行き先の名前は出さない。
final class CompassViewController: UIViewController {
    private let store: WalkStore
    private let dial = CompassDial()
    private let head = makeLabel("", Theme.display(19), .white, align: .center)
    private let sub = makeLabel("", Theme.body(12), Theme.mutedDark, align: .center)
    private let distValue = makeLabel("—", Theme.mono(22, .semibold), .white, align: .center)
    private let minsValue = makeLabel("—", Theme.mono(22, .semibold), .white, align: .center)
    private let brgValue  = makeLabel("—", Theme.mono(22, .semibold), .white, align: .center)
    private let arriveButton = UIButton(type: .system)

    init(store: WalkStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    var onArrive: (() -> Void)?
    var onGiveUp: (() -> Void)?
    /// デモのときだけ出す。行き先へ自動で歩く。
    var demoWalk: (() -> Void)?
    private let hintCard = HintCard()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sumi

        // 押せるものは押せる顔で出す。到着したら緑のベタに変える。
        arriveButton.configuration = Theme.buttonConfig(.secondary, store.t("I'm here", "ここにいます"))
        // 着いていないのに押して終わってしまうのを防ぐ。遠いときだけ確認する。
        arriveButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.store.arrived { self.onArrive?(); return }
            let left = Int((self.store.remaining ?? 0).rounded())
            Theme.confirm(on: self,
                title: self.store.t("You are still \(left) m away", "まだ\(left)m あります"),
                message: self.store.t("Ending here counts as arriving. Do it anyway?",
                                      "ここで終えると到着あつかいになります。それでも終えますか?"),
                keep: self.store.t("Keep walking", "まだ歩く"),
                go: self.store.t("End here", "ここで終える")) { self.onArrive?() }
        }, for: .touchUpInside)

        // やめると、引いた行き先は消える。取り消せないので確かめる。
        let giveUp = Theme.button(.tertiary, store.t("Give up", "やめる"), small: true) { [weak self] in
            guard let self else { return }
            Theme.confirm(on: self,
                title: self.store.t("Give up on this walk?", "この散歩をやめますか?"),
                message: self.store.t("The place we drew for you is lost. You can draw again from the map.",
                                      "引いた行き先は消えます。地図から引き直せます。"),
                keep: self.store.t("Keep walking", "まだ歩く"),
                go: self.store.t("Give up", "やめる")) { self.onGiveUp?() }
        }

        dial.translatesAutoresizingMaskIntoConstraints = false
        dial.heightAnchor.constraint(equalToConstant: 290).isActive = true

        let metrics = stack(.horizontal, 22, [
            metric(distValue, store.t("LEFT", "のこり")),
            metric(minsValue, store.t("ON FOOT", "とほ")),
            metric(brgValue,  store.t("BEARING", "ほうい"))
        ])
        metrics.distribution = .fillEqually

        hintCard.onUse = { [weak self] in
            guard let self else { return }
            self.store.hintsUsed = min(2, self.store.hintsUsed + 1)
            self.refresh()
        }
        // 見出しの2行は「あてもなく」だけ。駅まで抜けるコースの寄り道は
        // 静けさで選んでいないので、「静かな場所です」が嘘になる。
        let headBlock = stack(.vertical, 5, [head, sub])
        headBlock.isHidden = (store.course != nil)
        var rows: [UIView] = [headBlock, dial, metrics, hintCard, arriveButton]
        if demoWalk != nil {
            let w = Theme.button(.tertiary,
                                 store.t("Walk there (simulation)", "行き先まで歩く（シミュレーション）"),
                                 small: true) { [weak self] in self?.demoWalk?() }
            w.configuration?.baseForegroundColor = Theme.mid
            w.configuration?.background.strokeColor = Theme.mid.withAlphaComponent(0.5)
            rows.append(w)
        }
        rows.append(giveUp)
        let col = stack(.vertical, 20, rows)
        view.addSubview(col)
        col.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            col.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        refresh()
    }

    private func metric(_ value: UILabel, _ key: String) -> UIView {
        let k = UILabel(); k.attributedText = Theme.label(key); k.textAlignment = .center
        return stack(.vertical, 3, [value, k])
    }

    func refresh() {
        head.text = store.t("We are not telling you yet", "行き先は ひみつ")
        hintCard.render(store: store)
        guard let h = store.here, let d = store.destination else { return }
        let bearing = Geo.bearing(h, d.coordinate)
        let rot = store.heading == nil ? bearing : bearing - store.heading!
        var p: Double?
        if let o = store.origin {
            let total = Geo.distance(o, d.coordinate)
            if total > 1, let r = store.remaining { p = min(1, max(0, 1 - r / total)) }
        }
        dial.point(to: rot, progressValue: p)

        let r = store.remaining ?? 0
        distValue.text = r >= 2000 ? String(format: "%.1fkm", r / 1000)
                                   : "\(Int((r / 10).rounded()) * 10)m"
        minsValue.text = "\(store.minutesLeft)"
        brgValue.text = String(format: "%03.0f°", bearing)

        let dir = Geo.compassEN[Geo.compassIndex(bearing)]
        let dirJA = Geo.compassJA[Geo.compassIndex(bearing)]
        sub.text = store.heading == nil
            ? store.t("Follow the green tip. Something quiet, \(dir) of here. The dial is north-up.",
                      "緑の先を追ってください。ここから\(dirJA)の、静かな場所です。文字盤は北が上で固定です。")
            : store.t("Follow the green tip. Something quiet, \(dir) of here.",
                      "緑の先を追ってください。ここから\(dirJA)の、静かな場所です。")

        // 着いたら緑のベタに上げる。着く前も押せるので、灰色のベタにはしない。
        let there = store.arrived
        arriveButton.configuration = Theme.buttonConfig(
            there ? .primary : .secondary,
            there ? store.t("You made it", "着きました") : store.t("I'm here", "ここにいます"))
    }
}

/// ヒントは2回。迷って欲しくなったら使う。
/// 1回目で種類、2回目で混み具合と頭の一文字。名前そのものは最後まで出さない。
final class HintCard: UIView {
    var onUse: (() -> Void)?
    private let button = UIButton(type: .system)
    private let body = UIStackView()
    private let empty = makeLabel("", Theme.body(11.5), Theme.mutedDark, lines: 0)

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.sumi2
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Theme.hairlineDk.cgColor

        var c = UIButton.Configuration.plain()
        c.image = UIImage(systemName: "lightbulb")
        c.imagePadding = 6
        c.baseForegroundColor = Theme.aiLight
        c.contentInsets = .init(top: 8, leading: 10, bottom: 8, trailing: 10)
        button.configuration = c
        button.addAction(UIAction { [weak self] _ in self?.onUse?() }, for: .touchUpInside)

        body.axis = .vertical; body.spacing = 5
        let col = stack(.vertical, 8, [
            stack(.horizontal, 8, [UIView(), button], align: .center), empty, body
        ])
        addSubview(col)
        col.pin(to: self, insets: .init(top: 10, left: 13, bottom: 12, right: 13))
    }
    required init?(coder: NSCoder) { fatalError() }

    func render(store: WalkStore) {
        body.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let used = store.hintsUsed
        empty.text = store.t("Two hints. Spend them when you are lost enough to want one.",
                             "ヒントは2回。迷って欲しくなったら使ってください。")
        button.configuration?.attributedTitle = AttributedString(
            used >= 2 ? store.t("No hints left", "ヒントはもうありません")
                      : store.t("Use a hint (\(2 - used) left)", "ヒントを使う（あと\(2 - used)）"),
            attributes: AttributeContainer([.font: Theme.body(12, .semibold)]))
        button.isEnabled = used < 2
        button.alpha = used < 2 ? 1 : 0.45
        empty.isHidden = used > 0
        guard let d = store.destination else { return }
        if used >= 1 {
            body.addArrangedSubview(line(store.t("What it is", "なにか"), store.category(d)))
        }
        if used >= 2 {
            let v = store.crowd.level(d, at: store.clock())
            body.addArrangedSubview(line(store.t("How busy", "混み具合"),
                                         store.t("~\(v)% of peak, estimated", "ピーク比 およそ\(v)%（予想）")))
            body.addArrangedSubview(line(store.t("First letter", "頭の一文字"), store.firstLetter(d)))
        }
    }

    private func line(_ k: String, _ v: String) -> UIView {
        let key = UILabel(); key.attributedText = Theme.label(k)
        key.setContentHuggingPriority(.required, for: .horizontal)
        return stack(.horizontal, 10, [key, UIView(),
                                       makeLabel(v, Theme.body(12.5, .semibold), .white)],
                     align: .firstBaseline)
    }
}
