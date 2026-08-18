import Foundation

/// 表示の言語。英語が主で、日本語は切り替えで出す。
public enum Lang: String, Sendable { case en, ja }

/// 分類の言い換えと、正体を伏せた一行。
/// 一行は分類ごとに書き分ける。3文を全部に使い回すと、3枚が同じ顔になる。
public enum Copy {

    /// 区の分類は日本語のままなので、英語で見ている人には言い換える。
    public static func category(_ raw: String, _ lang: Lang) -> String {
        if lang == .ja { return jaCategory[raw] ?? raw }
        return enCategory[raw] ?? (raw.contains("飲食") ? "Place to eat" : "Landmark")
    }

    static let enCategory: [String: String] = [
        "文化財のある寺社": "Temple or shrine",
        "名所・史跡": "Historic site",
        "文化財": "Registered property",
        "文化": "Cultural property",
        "有形民俗文化財": "Folk property",
        "美術工芸品": "Art or craft holding",
        "博物館": "Museum",
        "観光施設": "Visitor site",
        "観光": "Visitor site",
        "飲食店営業（そば）": "Soba house",
        "飲食店営業（一般・ラーメン）": "Ramen shop",
        "飲食店営業（すし屋）": "Sushi counter",
        "飲食店営業（一般・うなぎ）": "Unagi house",
        "飲食店営業（一般・とんかつ）": "Tonkatsu shop",
        "飲食店営業（一般・お好み焼きもんじゃ）": "Okonomiyaki griddle",
        "飲食店営業（一般・おでん）": "Oden counter",
        "飲食店営業（一般・その他）": "Small kitchen",
        "駅": "Station"
    ]
    static let jaCategory: [String: String] = [
        "飲食店営業（そば）": "そば",
        "飲食店営業（一般・ラーメン）": "ラーメン",
        "飲食店営業（すし屋）": "すし",
        "飲食店営業（一般・うなぎ）": "うなぎ",
        "飲食店営業（一般・とんかつ）": "とんかつ",
        "飲食店営業（一般・お好み焼きもんじゃ）": "お好み焼き",
        "飲食店営業（一般・おでん）": "おでん",
        "飲食店営業（一般・その他）": "小さな店"
    ]

    /// 分類ごとの一行。名前も場所も明かさず、行ってみたくなるところまで。
    static let lines: [String: [(String, String)]] = [
        "soba": [
            ("Buckwheat, cut this morning", "今朝打った蕎麦がある"),
            ("A counter, a kettle, and steam", "釜の湯気が上がる台の向こう"),
            ("Cold noodles on a slatted tray", "簀の子に上がった冷たい一枚"),
            ("The kind of place with no menu on the wall", "壁に品書きの無い店"),
            ("Six seats and a queue that knows", "六席と、知っている人の列"),
            ("Dark soup, the eastern way", "汁の黒い、江戸の側"),
            ("They close when the buckwheat runs out", "蕎麦が切れたら仕舞う"),
            ("A shop that has outlasted the street", "通りより長く続いている店")
        ],
        "ramen": [
            ("A bowl worth the walk", "歩いた甲斐のある一杯"),
            ("Steam on the window from the street", "外から見える曇った硝子"),
            ("One pot, going since morning", "朝から火の落ちない寸胴"),
            ("A ticket machine older than you", "自分より古い券売機"),
            ("Ten seats, all facing the same way", "十席、みな同じ向き"),
            ("The soup takes two days", "二日かかる出汁"),
            ("A shop with one thing on the menu", "品書きが一つだけの店"),
            ("Loud kitchen, quiet street", "静かな通りの、うるさい厨房")
        ],
        "sushi": [
            ("A counter, and whatever came in today", "今日入ったものと、台がひとつ"),
            ("No prices on the wall", "値の書いていない壁"),
            ("Eight seats and a glass case", "八席と硝子のケース"),
            ("The rice is warm, the fish is not", "飯は温かく、種は冷たい"),
            ("A shop the neighbourhood keeps to itself", "近所が抱えている店"),
            ("Someone has stood here for thirty years", "三十年、同じ場所に立っている"),
            ("Lunch is the cheap way in", "昼が入口になる店")
        ],
        "unagi": [
            ("Charcoal, and the smell from two doors down", "二軒先まで届く炭の匂い"),
            ("They start grilling before you order", "頼む前から焼きはじめる"),
            ("A shop that only knows one dish", "一品しか知らない店"),
            ("Lacquer boxes, stacked and waiting", "重ねて待っている重箱"),
            ("The sauce is older than the building", "建物より古い蒸れ")
        ],
        "tonkatsu": [
            ("Oil at the right temperature since 11", "十一時から同じ温度の油"),
            ("Cabbage, endlessly", "きりの無い千切り"),
            ("A shop where the queue moves fast", "列の進みが速い店")
        ],
        "okonomiyaki": [
            ("A hot plate you cook on yourself", "自分で焼く鉄板"),
            ("Monja, and a small metal spatula", "もんじゃと、小さなヘラ"),
            ("The table is the stove", "卓が竈になっている"),
            ("A room that smells of sauce and steam", "ソースと湯気の部屋")
        ],
        "oden": [
            ("A simmering pot behind the glass", "硝子の向こうで煮えている"),
            ("Pick what looks good and sit down", "旨そうなのを指して座る")
        ],
        "food": [
            ("A small sign. The locals know it", "看板は小さい。近所の人が通っている"),
            ("One street back from the crowd", "人通りから一本入ったところ"),
            ("A light on in a narrow lane", "路地に灯りがともっている"),
            ("A kitchen you can see into", "厨房の見える店")
        ],
        "temple": [
            ("A gate, and no one behind it", "門の先に、誰もいない"),
            ("A precinct the guidebooks skip", "案内図には出てこない境内"),
            ("Gravel, and the sound of your own feet", "玉砂利と、自分の足音"),
            ("Older than everything around it", "まわりの何より古い"),
            ("Someone still sweeps here every morning", "毎朝、誰かが掃いている"),
            ("A hall that survived the fires", "火をくぐり抜けた堂"),
            ("Cedar, incense, and shade", "杉と線香と日陰"),
            ("Open to the street, and empty", "通りに開いていて、無人"),
            ("A bell that still gets rung", "いまも撞かれている鐘"),
            ("Stone steps worn in the middle", "真ん中がへこんだ石段")
        ],
        "shrine": [
            ("A small shrine between two houses", "家と家のあいだの社"),
            ("Vermilion, gone soft with age", "褪せた朱"),
            ("Foxes, and someone's fresh offering", "狐と、新しい供え物"),
            ("A rope, a bell, and no queue", "鈴緒と、誰もいない前")
        ],
        "historic": [
            ("A marker where something used to be", "何かがあった場所の印"),
            ("The city forgot this on purpose", "街が置いていった一角"),
            ("A stone with a date on it", "年号の彫られた石"),
            ("Someone was born here, or died here", "誰かが生まれたか、死んだ場所"),
            ("A bridge that no longer crosses anything", "何も渡さなくなった橋"),
            ("The old road ran through here", "昔の道が通っていた")
        ],
        "museum": [
            ("A room someone assembled with care", "誰かが丁寧に並べた部屋"),
            ("Small, and free, and rarely busy", "小さくて、ただで、空いている")
        ],
        "park": [
            ("Somewhere to sit and not be hurried", "誰にも急かされずに座れる場所"),
            ("Trees, and the street falling away", "木があって、通りの音が遠くなる"),
            ("A bench, and time you did not plan", "ベンチと、予定していなかった時間")
        ],
        "landmark": [
            ("Something old, still standing here", "古いものが、そのまま残っている"),
            ("Worth the detour, quietly", "静かに、寄る値打ちがある"),
            ("The kind of place you walk past", "いつも通り過ぎている場所")
        ]
    ]

    /// 分類から、一行の束を選ぶ。
    static func bucket(_ category: String, kind: Kind) -> String {
        if category.contains("そば") { return "soba" }
        if category.contains("ラーメン") { return "ramen" }
        if category.contains("すし") { return "sushi" }
        if category.contains("うなぎ") { return "unagi" }
        if category.contains("とんかつ") { return "tonkatsu" }
        if category.contains("お好み焼き") { return "okonomiyaki" }
        if category.contains("おでん") { return "oden" }
        if kind == .food { return "food" }
        if category.contains("寺社") { return "temple" }
        if category.contains("史跡") || category.contains("名所") { return "historic" }
        if category.contains("博物") { return "museum" }
        if category.contains("公園") || category.contains("庭園") { return "park" }
        return "landmark"
    }

    /// 正体を伏せた一行。同じ場所には毎回同じ文が当たる。
    /// 引き直すたびに文が変わると、嘘くさくなるので。
    public static func teaser(_ spot: Spot, _ lang: Lang, avoid used: Set<String> = []) -> String {
        let set = lines[bucket(spot.category, kind: spot.kind)] ?? lines["landmark"]!
        var h = 5381
        for u in spot.name.unicodeScalars { h = (h &* 33) &+ Int(u.value) }
        let start = abs(h) % set.count
        // 同じ回の3枚で文が重なったときだけずらす。手を抜いたように見えるので。
        for i in 0..<set.count {
            let c = set[(start + i) % set.count]
            let t = lang == .ja ? c.1 : c.0
            if !used.contains(t) { return t }
        }
        let c = set[start]
        return lang == .ja ? c.1 : c.0
    }

    /// 名前の頭。英語で見ている人には、読みが分かっていればその頭を返す。
    public static func firstLetter(_ spot: Spot, _ lang: Lang, english: String?) -> String {
        if lang == .en, let e = english, !e.isEmpty { return String(e.prefix(1)) + "…" }
        return String(spot.name.prefix(1)) + "…"
    }
}
