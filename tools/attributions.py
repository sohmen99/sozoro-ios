#!/usr/bin/env python3
"""写真の出典一覧を作り直す。

CC BY / CC BY-SA のものは、撮影者・ライセンス・出所を示す義務がある。
アプリの画面には「撮影者 · ライセンス · Wikimedia Commons」しか出せないので、
リンクと「縮小した」という但し書きはここで受ける。サポートURLがこの一覧を指す。

    python3 tools/attributions.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Sources/SozoroCore/Resources/photos.json")
OUT = os.path.join(ROOT, "ATTRIBUTIONS.md")


def table(rows):
    out = ["| 行き先 | 撮影者 | ライセンス | 元のページ |", "|---|---|---|---|"]
    for name, v in rows:
        lic = f"[{v['licence']}]({v['licenceURL']})" if v.get("licenceURL") else v["licence"]
        out.append(f"| {name} | {v['artist'] or '—'} | {lic} | [Commons]({v['page']}) |")
    return out


def main():
    photos = sorted(json.load(open(SRC, encoding="utf-8")).items())
    need = [r for r in photos if r[1]["licence"].startswith("CC BY")]
    free = [r for r in photos if not r[1]["licence"].startswith("CC BY")]

    L = [
        "# 写真の出典\n",
        f"行き先の写真{len(photos)}枚は Wikimedia Commons のものです。"
        "**このリポジトリの MIT には入りません。**",
        "それぞれ元のライセンスのまま。アプリ内では到着画面に"
        "「撮影者 · ライセンス · Wikimedia Commons」を出しています。\n",
        "いずれも **480pxに縮小し、JPEGで再保存**したものを同梱しています。",
        "切り抜きや加工はしていません（大きさと形式の変更は、CC のいう翻案にはあたりません）。\n",
        f"## クレジットの要るもの（{len(need)}件）\n",
        "CC BY / CC BY-SA。撮影者・ライセンス・出所を示す義務があります。\n",
        *table(need),
        f"\n## 法的には不要だが、出しているもの（{len(free)}件）\n",
        "パブリックドメインと CC0。義務はありませんが、撮った人の名前は出しています。\n",
        *table(free),
        "\n---\n",
        "この一覧は `tools/photos.py` が書き出す `Resources/photos.json` から作っています。",
        "写真を足したら `python3 tools/attributions.py` で作り直してください。\n",
    ]
    open(OUT, "w", encoding="utf-8").write("\n".join(L))
    print(f"ATTRIBUTIONS.md: {len(need)}件がクレジット必須 / {len(free)}件が任意")


if __name__ == "__main__":
    main()
