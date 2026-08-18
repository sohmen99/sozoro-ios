#!/usr/bin/env python3
"""選定185件の照合表から、行き先の実写真を焼き込む。

通信はここ（ビルド時）だけ。アプリは一切取りに行かない。
会場の回線が弱くても、Wikimedia が落ちても、写真は出る。

採るのは **その場所そのものを写したものだけ**。
- 画像対象(image_subject) が self でないものは、別の建物の写真なので採らない
- 表の区・町丁とファイル名が食い違うものは、同名の別の寺なので採らない
- ファイル名に名前が入っていない連番写真は、確かめようがないので採らない

撮影者とライセンスは表のクレジット欄ではなく Commons API から引く。
表の文字列は手で書いたものなので、出典として出すには弱い。

    python3 tools/photos.py ~/Downloads/sozoro_matched_185.xlsx
"""
import json, os, re, sys, ssl, html, urllib.parse, urllib.request, zipfile
import xml.etree.ElementTree as ET
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Sources/SozoroCore/Resources")
OUT = os.path.join(RES, "photos")
UA = {"User-Agent": "sozoro-hackathon/0.1 (https://github.com/sohmen99/sozoro-ios)"}
CTX = ssl.create_default_context()

# 手で確かめて外したもの。理由を残しておかないと、次に誰かが戻してしまう。
EXCLUDE = {
    "長久院": "ファイル名が Tokyo_-_Yanaka_083 で、その寺だと確かめられない",
    "本行寺": "写真は元浅草の本行寺。行き先は荒川区西日暮里の同名の寺",
    "筆や":   "写真は総持院。表がこの筆屋を隣の寺に照合している",
}
WARD = {"台東区": "taito", "荒川区": "arakawa", "墨田区": "sumida", "文京区": "bunkyo"}


def read_xlsx(path):
    z = zipfile.ZipFile(path)
    N = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
    R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
    rels = {r.get("Id"): r.get("Target")
            for r in ET.fromstring(z.read("xl/worksheets/_rels/sheet2.xml.rels"))}
    rows = []
    for row in ET.fromstring(z.read("xl/worksheets/sheet2.xml")).iter(N + "row"):
        cells = {}
        for c in row.iter(N + "c"):
            ref = re.match(r"[A-Z]+", c.get("r")).group()
            t, v = c.find(N + "is/" + N + "t"), c.find(N + "v")
            val = t.text if t is not None else (v.text if v is not None else "")
            if c.get(R + "id"):
                val = rels.get(c.get(R + "id"), val)
            cells[ref] = val or ""
        rows.append(cells)
    head = rows[0]
    return [{head[k]: r.get(k, "") for k in head} for r in rows[1:]]


def commons_name(url):
    # 表には原寸のURLと縮小版のURLが混ざっている。どちらからも元の名前を取る。
    m = re.match(r"https://upload\.wikimedia\.org/wikipedia/commons/thumb/"
                 r"[0-9a-f]/[0-9a-f]{2}/([^/]+)/", url)
    if m:
        return urllib.parse.unquote(m.group(1))
    m = re.match(r"https://upload\.wikimedia\.org/wikipedia/commons/"
                 r"[0-9a-f]/[0-9a-f]{2}/(.+)$", url)
    return urllib.parse.unquote(m.group(1)) if m else None


def api(titles):
    """Commons から縮小版のURL・撮影者・ライセンスをまとめて引く。"""
    got = {}
    for i in range(0, len(titles), 25):
        q = urllib.parse.urlencode({
            "action": "query", "titles": "|".join(titles[i:i + 25]),
            "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": "800",
            "iiextmetadatafilter": "Artist|LicenseShortName|LicenseUrl", "format": "json"})
        req = urllib.request.Request("https://commons.wikimedia.org/w/api.php?" + q, headers=UA)
        with urllib.request.urlopen(req, timeout=40, context=CTX) as r:
            j = json.load(r)
        back = {n["to"]: n["from"] for n in j["query"].get("normalized", [])}
        for p in j["query"]["pages"].values():
            ii = (p.get("imageinfo") or [None])[0]
            if not ii:
                continue
            ex = ii["extmetadata"]
            got[back.get(p["title"], p["title"])] = {
                "thumb": ii["thumburl"].split("?")[0],
                "page": ii["descriptionurl"],
                "artist": re.sub("<[^>]+>", "", html.unescape(
                    ex.get("Artist", {}).get("value", ""))).strip(),
                "licence": ex.get("LicenseShortName", {}).get("value", ""),
                "licenceURL": ex.get("LicenseUrl", {}).get("value", ""),
            }
    return got


WEB = os.path.expanduser("~/Documents/ハッカソン/index.html")


def write_web(index):
    """ウェブ版にも同じ58件を渡す。あちらは1枚のHTMLなので焼き込めない。
    Commons の縮小版を直に見て、取れなければ分類ごとの絵に落ちる（img.onerror）。"""
    if not os.path.exists(WEB):
        return
    # URLは API が返した幅のまま使う。Commons は任意の幅を受け付けなくなっていて、
    # 手で 480px などに書き換えると 400 が返る。
    body = ",\n  ".join(
        '"%s":["%s","%s"]' % (n, v["url"], (v["artist"] + " · " + v["licence"] +
                                            " · Wikimedia Commons").replace('"', "'"))
        for n, v in sorted(index.items()))
    block = (
        "/* 行き先の写真。iOS 版と同じ照合表・同じ除外で選んだ58件。\n"
        "   名前 -> [縮小版のURL, クレジット]。tools/photos.py が書き出す。 */\n"
        "var PHOTOS = {\n  " + body + "\n};\n\n")
    s = open(WEB, encoding="utf-8").read()
    mark_a, mark_b = "/* 行き先の写真。", "var SPOTS = ["
    if mark_a in s:
        s = s[:s.index(mark_a)] + block + s[s.index(mark_b):]
    else:
        s = s[:s.index(mark_b)] + block + s[s.index(mark_b):]
    open(WEB, "w", encoding="utf-8").write(s)
    print(f"ウェブ版の PHOTOS も書き換えた（{len(index)}件）")


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
        "~/Downloads/sozoro_matched_185.xlsx")
    spots = {s["name"] for s in json.load(open(os.path.join(RES, "spots.json")))}
    rows = read_xlsx(src)

    keep, dropped = [], []
    for x in rows:
        url = x["画像URL"]
        name = (x["選定サイト名称"] if x["選定サイト名称"] in spots
                else x["DB名称"] if x["DB名称"] in spots else None)
        if not url.startswith("http") or not name:
            continue
        if x["画像対象(image_subject)"] != "self":
            dropped.append((name, "被写体がその場所ではない")); continue
        if name in EXCLUDE:
            dropped.append((name, EXCLUDE[name])); continue
        f = commons_name(url)
        if not f:
            dropped.append((name, "Commons のURLではない")); continue
        low = re.sub(r"[^a-z]", "", f.lower())
        wrong = [k for k, v in WARD.items() if k != x["区"] and v in low]
        if wrong and WARD.get(x["区"], "\0") not in low:
            dropped.append((name, f"区ちがい（表は{x['区']}、写真は{wrong[0]}）")); continue
        keep.append((name, f))

    titles = sorted({"File:" + f for _, f in keep})
    print(f"採る {len(keep)}件 / ファイル {len(titles)}本 / 落とす {len(dropped)}件")
    info = api(titles)

    os.makedirs(OUT, exist_ok=True)
    index, total = {}, 0
    for name, f in keep:
        v = info.get("File:" + f)
        if not v:
            dropped.append((name, "Commons が返さなかった")); continue
        stem = re.sub(r"[^A-Za-z0-9]", "_", f.rsplit(".", 1)[0])[:60]
        rel = f"photos/{stem}.jpg"
        dst = os.path.join(RES, rel)
        if not os.path.exists(dst):
            tmp = dst + ".src"
            with urllib.request.urlopen(
                    urllib.request.Request(v["thumb"], headers=UA), timeout=60, context=CTX) as r:
                open(tmp, "wb").write(r.read())
            # 三択では 84px、到着でも横幅いっぱい。480 あれば足りる。
            subprocess.run(["sips", "-Z", "480", "-s", "format", "jpeg",
                            "-s", "formatOptions", "72", tmp, "--out", dst],
                           capture_output=True, check=True)
            os.remove(tmp)
        total += os.path.getsize(dst)
        # SPM の process はフォルダを畳むので、索きは名前だけで持つ。
        index[name] = {"file": stem, "artist": v["artist"], "licence": v["licence"],
                       "licenceURL": v["licenceURL"], "page": v["page"],
                       # ウェブ版は焼き込めないので、Commons の縮小版を直に見る
                       "url": v["thumb"]}

    json.dump(index, open(os.path.join(RES, "photos.json"), "w"),
              ensure_ascii=False, indent=1, sort_keys=True)
    print(f"焼き込み {len(index)}件 / {total/1024/1024:.1f}MB → Resources/photos/")
    write_web(index)
    print("\n落としたもの:")
    for n, why in sorted(set(dropped)):
        print(f"  {n:<16}{why}")


if __name__ == "__main__":
    main()
