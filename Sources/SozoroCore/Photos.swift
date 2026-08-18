import Foundation

/// 行き先の実写真。ビルド時に焼き込んであるので、アプリは取りに行かない。
///
/// 採ってあるのは **その場所そのものを写したものだけ**。別の建物の写真、
/// 同名の別の寺、名前の入っていない連番写真は `tools/photos.py` が落としている。
/// 出所は Wikimedia Commons で、撮影者とライセンスは Commons API から引いた値。
public struct Photo: Codable, Sendable {
    /// 束の中のファイル名（拡張子なし）
    public let file: String
    public let artist: String
    public let licence: String
    public let licenceURL: String
    /// Commons のファイル説明ページ。出典として辿れるようにしておく。
    public let page: String

    /// 表示に添える一行。クレジットの要らないライセンスでも、撮った人の名前は出す。
    public var credit: String {
        artist.isEmpty ? "Wikimedia Commons · \(licence)"
                       : "\(artist) · \(licence) · Wikimedia Commons"
    }
}

extension SozoroData {
    /// その行き先の写真。無ければ nil。
    public func photo(for spot: Spot) -> Photo? { photos[spot.name] }

    /// 束の中の実体。`.process` はフォルダを畳むので、名前だけで索く。
    public func photoURL(for spot: Spot) -> URL? {
        guard let p = photo(for: spot) else { return nil }
        return Bundle.module.url(forResource: p.file, withExtension: "jpg")
            ?? Bundle.module.url(forResource: "photos/" + p.file, withExtension: "jpg")
    }
}
