#!/usr/bin/env swift
// アプリのアイコン。羅針盤だと一目で分かることだけを狙う。
//
// 画面のキャプチャを切り抜かずに、同じ図をここで描き直している。
// 60px まで縮むと、点線の輪と斜めの目盛りと N/E/S/W は潰れて濁るだけなので、
// 外輪・四方の目盛り・針の3つに絞ってある。針は画面と同じ北東向き。
//
//   swift tools/appicon.swift
//   → App/Sozoro/Assets.xcassets/AppIcon.appiconset/icon-1024.png

import AppKit
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let c = CGPoint(x: side / 2, y: side / 2)
// 300 の座標系で組んである図を、1024 に伸ばす。
let k = side / 300.0

let sumi = NSColor(srgbRed: 0x14 / 255, green: 0x17 / 255, blue: 0x1C / 255, alpha: 1)
let green = NSColor(srgbRed: 0x35 / 255, green: 0xB7 / 255, blue: 0x9A / 255, alpha: 1)
let ring = NSColor(srgbRed: 0x5A / 255, green: 0x65 / 255, blue: 0x75 / 255, alpha: 1)
let tail = NSColor(srgbRed: 0x3B / 255, green: 0x43 / 255, blue: 0x4F / 255, alpha: 1)

// 1024×1024 の枡を自分で用意する。画面の倍率に引きずられないように。
// 透明の面は持たせない（noneSkipLast）。角丸も透明も Apple が弾く。
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    print("枡を作れない"); exit(1)
}

// 地。角は丸めない。透明も入れない。どちらも Apple が弾く。
ctx.setFillColor(sumi.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

func circle(_ r: Double, _ colour: NSColor, _ width: Double) {
    ctx.setStrokeColor(colour.cgColor)
    ctx.setLineWidth(width * k)
    ctx.addEllipse(in: CGRect(x: c.x - r * k, y: c.y - r * k, width: r * 2 * k, height: r * 2 * k))
    ctx.strokePath()
}

// 外輪と内輪。60px まで縮むので、画面よりずっと太くする。
circle(126, ring, 7)
circle(100, ring.withAlphaComponent(0.5), 4)

// 四方の目盛り。斜めは入れない。小さくすると団子になる。
ctx.setStrokeColor(ring.cgColor)
ctx.setLineWidth(9 * k)
ctx.setLineCap(.round)
for a in stride(from: 0.0, to: 360.0, by: 90.0) {
    let r = a * .pi / 180
    ctx.move(to: CGPoint(x: c.x + sin(r) * 142 * k, y: c.y + cos(r) * 142 * k))
    ctx.addLine(to: CGPoint(x: c.x + sin(r) * 118 * k, y: c.y + cos(r) * 118 * k))
}
ctx.strokePath()

// 針。画面と同じで、行き先側だけを矢にして、反対は短い重りにする。
// AppKit は y が上向きなので、画面の座標をそのまま使わずに符号を返す。
ctx.saveGState()
ctx.translateBy(x: c.x, y: c.y)
ctx.rotate(by: -45 * .pi / 180)          // 北東を向く

ctx.setFillColor(tail.cgColor)
ctx.beginPath()
ctx.move(to: CGPoint(x: 0, y: -34 * k))
ctx.addLine(to: CGPoint(x: -16 * k, y: -66 * k))
ctx.addLine(to: CGPoint(x: 16 * k, y: -66 * k))
ctx.closePath(); ctx.fillPath()
ctx.fill(CGRect(x: -4.5 * k, y: -66 * k, width: 9 * k, height: 66 * k))

ctx.setFillColor(green.cgColor)
ctx.fill(CGRect(x: -7 * k, y: 0, width: 14 * k, height: 78 * k))
ctx.beginPath()
ctx.move(to: CGPoint(x: 0, y: 124 * k))
ctx.addLine(to: CGPoint(x: -33 * k, y: 68 * k))
ctx.addLine(to: CGPoint(x: 0, y: 82 * k))
ctx.addLine(to: CGPoint(x: 33 * k, y: 68 * k))
ctx.closePath(); ctx.fillPath()

// 軸。地の色で抜いて、緑で縁取る。
ctx.setFillColor(sumi.cgColor)
ctx.fillEllipse(in: CGRect(x: -12 * k, y: -12 * k, width: 24 * k, height: 24 * k))
ctx.setStrokeColor(green.cgColor)
ctx.setLineWidth(6 * k)
ctx.strokeEllipse(in: CGRect(x: -12 * k, y: -12 * k, width: 24 * k, height: 24 * k))
ctx.restoreGState()

let out = URL(fileURLWithPath: "App/Sozoro/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
guard let cg = ctx.makeImage(),
      let dst = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)
else { print("書き出せない"); exit(1) }
CGImageDestinationAddImage(dst, cg, nil)
CGImageDestinationFinalize(dst)
print("書き出した: \(out.path)")
