# SozoroCore

**Tokyo sozoro の iOS 版。ロジックはウェブ版と同じ数字を返すことをテストで確かめてあります。**

```sh
open App/Sozoro.xcodeproj      # Xcode で開いて ⌘R
```

シミュレータでも実機でも動きます。実機で見るときは、Signing の Team を自分のものに
変えてください（`PRODUCT_BUNDLE_IDENTIFIER` は `dev.sozoro.app` にしてあります）。
位置情報の許可文は Info.plist ではなくビルド設定に入れてあるので、別ファイルはありません。

ウェブ版（[tokyo-sozoro](https://github.com/sohmen99/tokyo-sozoro)）と**同じ数字を返すことをテストで確かめて**あります。
SwiftUI でも UIKit でも、この上に好きな画面を載せられます。

```
swift test          # ウェブ版が出した正解値と突き合わせる
```

※ Xcode を入れてあっても `xcode-select` が CommandLineTools を指していると XCTest が見つかりません。
その場合は `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。

---

## 入っているもの

### アプリ（`App/`）— UIKit

| | |
|---|---|
| `Theme` | ウェブ版の色と字。墨・和紙・藍・混雑の三段 |
| `SozoroApp` | AppDelegate。窓に `RootViewController` を差すだけ |
| `RootViewController` | **画面をひとつ持って差し替える。遷移はここに集約**。表紙→地図→三択→コンパス→到着→印 |
| `CoverViewController` | 表紙。約束だけ示して、抽選の仕組みは明かさない |
| `MapViewController` | 地図に混み具合を色で置く。上のバーから表紙・印・デモへ |
| `SheetView` | 気分のチップと歩き方の行。選択は墨で塗りつぶす |
| `PickViewController` | 三択。ぼかした色と伏せた一行と距離だけ |
| `CompassViewController` | CALayer の文字盤。針は片側、文字は回さず立てる |
| `ArrivalViewController` | 到着。正体を出して、続けるか終えるかを聞く |
| `RewardsViewController` | 印15種と歩いた記録 |
| `DemoMode` / `DemoPanel` | 場所と時刻を置いて外に出ずに通す。地図を叩くとそこに立つ |
| `LocationService` | CLLocationManager の薄い包み。真北が取れないときは nil |
| `WalkStore` | 状態をひとつに集めたもの |

### プレビュー

`RootViewController.swift` の末尾に**6枚**あります。Canvas（⌥⌘↩）を出すと、
表紙・地図・三択・コンパス・到着・印がそれぞれ出ます。

```swift
#Preview("3 Picks") { RootViewController(store: .preview(stage: .picking), start: .picks) }
```

`WalkStore.preview(stage:)` が上野に立った状態を作るので、**位置情報も実機も要りません。**
プレビューでは `LocationService` を起こさないので、許可も出ません。

`RootViewController.swift` の頭に `import SwiftUI` が入っています。**消さないでください。**
`#Preview` が生成する中継コードが `SwiftUI.__designTimeFloat` などを import するので、
UIKit しか使っていなくても SwiftUI を依存に入れておかないと、
プレビューだけが `no such module 'SwiftUI'` で落ちます。ビルドは通るので気づきにくい。

### デモモード

地図の右上の杖のボタンで入ります。ウェブ版の `?demo=1` と同じで、

- **時刻のつまみ** … 混雑推定も営業時間もこの時刻に従う
- **平日 / 休日** … 人流の休日昼・平日昼が入れ替わる
- **地図を叩く** … その場所に立つ
- **×1 / ×10 / ×60** … コンパス画面から自動で歩く。×60 なら15分が15秒

**シミュレータでは実測が取れないので、こちらが本番の確認手段になります。**
自動歩行は直線を進むぶん道のりの1.3倍だけ遅く進めてあるので、
「徒歩15分」と出したら本当に15分（×60なら15秒）かかります。

### ロジック（`Sources/SozoroCore/`）

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

## まだ無いもの

- **共有**（`UIActivityViewController` に画像を渡すだけ）
- **ヒント2回**（コンパス画面で段階的に開示するやつ）
- シートを指で引き出す動き。いまは出しっぱなし
- 読みが分かっていない128件の日本語名。[sozoro-romaji](https://github.com/sohmen99/sozoro-romaji) が埋まったら差し込む

地図は MapKit なので、ウェブ版のベースマップ（SVG 71KB）と投影のコードと生成
スクリプトは要らなくなりました。「寄ると荒い」も起きません。

---

## 出典

台東区オープンデータ（CC-BY表示4.0国際）。本作品の内容について、台東区は一切保証しないものとする。
荒川区・墨田区・江東区・千代田区・中央区 文化財一覧／観光施設一覧（CC BY）。
OpenStreetMap contributors（ODbL）。国土交通省 全国の人流オープンデータ。
