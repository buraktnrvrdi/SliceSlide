import SwiftUI
import UIKit

/// 5 sezon × 60 bölüm. Her sezonun teması, mekaniği ve sezon sonu ödülü (kristal skini) vardır.
struct Season: Identifiable {
    static let levelsPer = 60

    let index: Int
    let name: String
    let tagline: String
    let mechanic: String
    let icon: String
    let paletteIDs: [Int]
    let rewardName: String
    let gemTop: UIColor
    let gemBottom: UIColor

    var id: Int { index }
    var number: Int { index + 1 }
    var firstLevel: Int { index * Season.levelsPer + 1 }
    var lastLevel: Int { (index + 1) * Season.levelsPer }
    var gemTopColor: Color { Color(gemTop) }
    var gemBottomColor: Color { Color(gemBottom) }

    static let all: [Season] = [
        Season(index: 0, name: L("Kristal Vadisi"), tagline: L("Her şey burada başlar"),
               mechanic: L("Temel kesim: şekli hedef yüzdelere göre böl. İlk 5 bölümde canlı önizleme seni yönlendirir."),
               icon: "diamond.fill", paletteIDs: [0, 1, 3, 5], rewardName: L("Kristal"),
               gemTop: UIColor(140, 228, 204), gemBottom: UIColor(92, 122, 206)),
        Season(index: 1, name: L("Buz Mağarası"), tagline: L("Donmuş sessizlik"),
               mechanic: L("Kayan çekirdekler: koyu çekirdekler şeklin içinde sürekli hareket eder. Çizgin çekirdeğe değerse kesim reddedilir."),
               icon: "snowflake", paletteIDs: [6, 7, 8, 6], rewardName: L("Buz Kristali"),
               gemTop: UIColor(214, 246, 255), gemBottom: UIColor(70, 128, 226)),
        Season(index: 2, name: L("Amber Çölü"), tagline: L("Gün batımında sıcak kum"),
               mechanic: L("Dönen kristal: şekil ilk kesime kadar yavaşça döner. Zamanlamanı yakala ve çizgini doğru anda çek."),
               icon: "sun.max.fill", paletteIDs: [9, 10, 11, 4], rewardName: L("Amber Taşı"),
               gemTop: UIColor(255, 226, 150), gemBottom: UIColor(214, 88, 70)),
        Season(index: 3, name: L("Zümrüt Ormanı"), tagline: L("Zaman akıyor"),
               mechanic: L("Süre baskısı: bölümlerin çoğunda zaman sınırı var. Üstteki çubuk bitmeden kesimlerini tamamla."),
               icon: "leaf.fill", paletteIDs: [12, 13, 14, 2], rewardName: L("Zümrüt"),
               gemTop: UIColor(196, 255, 214), gemBottom: UIColor(36, 140, 104)),
        Season(index: 4, name: L("Nova"), tagline: L("Ustalık sınavı"),
               mechanic: L("Usta seviyesi: dönen şekil, kayan çekirdekler, süre ve üçlü kesim bir arada. Önceki tüm sezonların toplamı."),
               icon: "sparkles", paletteIDs: [15, 16, 17, 15], rewardName: L("Nova Yıldızı"),
               gemTop: UIColor(255, 196, 232), gemBottom: UIColor(122, 84, 226)),
    ]

    static func of(level: Int) -> Season {
        all[max(0, min(all.count - 1, (level - 1) / levelsPer))]
    }
}
