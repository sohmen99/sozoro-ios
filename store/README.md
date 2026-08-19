# ストアに出すもの

## スクリーンショット

`screenshots-6.9/` … 1320 × 2868（iPhone 6.9インチ）5枚。App Store Connect が
必須にしているのはこの1サイズだけで、他のサイズは自動で縮められます。

| | 画面 | 何が写っているか |
|---|---|---|
| 1 | 表紙 | Follow the needle。混雑には送り込まない・道具はコンパスだけ |
| 2 | 地図 | 混雑の予想（緑・赤・紫）と、上野に立っている現在地。凡例と縮尺 |
| 3 | 三択 | 伏せた一行と距離。写真のある枚はぼかしてある |
| 4 | コンパス | 方角と残り距離だけ。行き先の名前は出ない |
| 5 | 到着 | 正体、実写真、撮影者とライセンス、歩いた数字 |

撮り方（シミュレータ／iPhone 16 Pro Max）:

```bash
xcrun simctl privacy booted grant location com.sohmen99.sozoro
xcrun simctl location booted set 35.7138,139.7772
xcrun simctl launch booted com.sohmen99.sozoro -screen cover      # 表紙
xcrun simctl launch booted com.sohmen99.sozoro -screen map        # 地図（実測の現在地）
xcrun simctl launch booted com.sohmen99.sozoro -screen picks -demo
xcrun simctl launch booted com.sohmen99.sozoro -screen arrival -demo
```

地図だけ `-demo` を付けません。付けるとシミュレーションの赤い帯が写ります。
三択・到着はシミュレーションでも帯が出ない画面なので、そのまま撮れます。

コンパスは `-demo` で撮ると「Walk there (simulation)」が写るので、撮影のときだけ
その行を隠して撮っています（アプリ側は変えていません）。

## 出典

到着画面の写真は Wikimedia Commons。撮影者とライセンスは画面に出しています。
スクリーンショット5枚目に写っているのは 光明寺（Higa4 / CC0）。
