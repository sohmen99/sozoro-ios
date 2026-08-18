# SozoroCore

**Tokyo sozoro のロジックを Swift に移したもの。UIは持っていません。**

ウェブ版（[tokyo-sozoro](https://github.com/sohmen99/tokyo-sozoro)）と**同じ数字を返すことをテストで確かめて**あります。
SwiftUI でも UIKit でも、この上に好きな画面を載せられます。

```
swift test          # ウェブ版が出した正解値と突き合わせる
```

※ Xcode を入れてあっても `xcode-select` が CommandLineTools を指していると XCTest が見つかりません。
その場合は `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。

---

## 入っているもの

| | |
|---|---|
| `Geo` | 距離・方位・移動。半正矢式。CoreLocation に依存しないので素で回る |
| `Crowd` | 混雑の3層モデル。人流メッシュの実測を距離の逆二乗で内挿し、時間帯と集客力に重ねる |
| `Draw` | 帯（徒歩15±7分）と重みつき抽選。静けさ・外向き・推しエリア。argmax ではない |
| `Route` | 向こうまで抜けるモード。方角から駅を決め、道筋を文化財で割る |
| `SozoroData` | 焼き込んだ候補地。通信は一度もしない |

```
Resources/spots.json      156  行き先（台東区・荒川区オープンデータ）
Resources/culture.json    629  道筋の寄り道（6区の文化財一覧）
Resources/stations.json    80  終点の駅（OpenStreetMap）
Resources/mesh.json       119  人流メッシュ（国土交通省）
Resources/names.json           読みが分かっている分の英語名
```

---

## 移植で合わせたところ

**同じ入力に同じ数字を返すこと**を8つのテストで縛っています。正解値は
`tools/export.js` がウェブ版の実装をそのまま走らせて吐いたものです。

| テスト | 見ているもの |
|---|---|
| `testGeo` | 5地点の総当たり20通りの距離と方位 |
| `testMeshNormalisation` | メッシュを0〜1に直す 5%〜95%点 |
| `testFootfall` | 人出の内挿（10通り） |
| `testCrowdLevel` | 混雑0〜100（6地点・2026-08-18 14:00） |
| `testBand` | 帯の中心923m・許容431m・探索1957m |
| `testWeight` | 抽選の重み（6地点、1e-9まで一致） |
| `testRouteOptions` | 5地点から出る31コースの方角・駅・分・道筋 |
| `testDrawAlwaysDealsThree` | 3地点×50回、3枚そろう・重複しない・帯を外さない |

移植中に1か所ずれました。**飲食の時間帯カーブを記憶で書いていた**ため、
混雑が1ずれ、そこから重みもずれます。テストが拾いました。

---

## ネイティブにする理由

ウェブ版で踏んだ不具合の大半が、CSSとDOMの事故でした。地図が寄ると荒い（合成レイヤーの
ラスタを引き伸ばしていた）、到着画面が潰れる（flexの縮み）、シートがはみ出す、
選択が見えない（未定義のCSS変数）、針が北をまたぐと逆回りする。**SwiftUI には無い種類の問題です。**

もっと効くのが位置情報と方位です。

```
ウェブ    navigator.geolocation + DeviceOrientationEvent
          iOSは許可を毎回、Androidはalphaを反転、屋内の初回測位が数km飛ぶ
ネイティブ CLLocationManager の trueHeading
          許可は一度、精度も更新頻度も桁違い、バックグラウンドも取れる
```

このアプリはコンパスが本体なので、ここが安定するのは大きい。
地図を MapKit にすれば、ベースマップの SVG 71KB と投影のコードと生成スクリプトが丸ごと消えます。

---

## 次にやること

- `LocationService`（CLLocationManager の薄い包み）
- `WalkStore`（記録と印。いまは localStorage）
- SwiftUI の画面：表紙・地図・シート・三択・コンパス・到着・印

ロジックはもう動くので、**画面を書けば動きます。**

---

## 出典

台東区オープンデータ（CC-BY表示4.0国際）。本作品の内容について、台東区は一切保証しないものとする。
荒川区・墨田区・江東区・千代田区・中央区 文化財一覧／観光施設一覧（CC BY）。
OpenStreetMap contributors（ODbL）。国土交通省 全国の人流オープンデータ。
