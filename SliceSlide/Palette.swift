import SwiftUI
import UIKit

extension UIColor {
    convenience init(_ r: Int, _ g: Int, _ b: Int, a: CGFloat = 1) {
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
    }
}

struct Palette: Identifiable {
    let id: Int
    let top: UIColor
    let bottom: UIColor
    let shapeTop: UIColor
    let shapeBottom: UIColor

    var topColor: Color { Color(top) }
    var bottomColor: Color { Color(bottom) }
    var shapeTopColor: Color { Color(shapeTop) }
    var shapeBottomColor: Color { Color(shapeBottom) }

    static let all: [Palette] = [
        Palette(id: 0, top: UIColor(157, 150, 226), bottom: UIColor(247, 203, 178),
                shapeTop: UIColor(140, 228, 204), shapeBottom: UIColor(92, 122, 206)),
        Palette(id: 1, top: UIColor(240, 156, 190), bottom: UIColor(253, 224, 172),
                shapeTop: UIColor(255, 220, 196), shapeBottom: UIColor(190, 100, 178)),
        Palette(id: 2, top: UIColor(116, 176, 232), bottom: UIColor(196, 240, 214),
                shapeTop: UIColor(255, 232, 196), shapeBottom: UIColor(238, 138, 146)),
        Palette(id: 3, top: UIColor(100, 122, 204), bottom: UIColor(242, 176, 204),
                shapeTop: UIColor(176, 242, 232), shapeBottom: UIColor(108, 148, 232)),
        Palette(id: 4, top: UIColor(250, 172, 142), bottom: UIColor(184, 154, 224),
                shapeTop: UIColor(255, 238, 196), shapeBottom: UIColor(238, 128, 152)),
        Palette(id: 5, top: UIColor(108, 200, 182), bottom: UIColor(242, 232, 174),
                shapeTop: UIColor(206, 176, 252), shapeBottom: UIColor(108, 118, 222)),
        // Buz Mağarası
        Palette(id: 6, top: UIColor(128, 190, 242), bottom: UIColor(226, 246, 253),
                shapeTop: UIColor(176, 228, 255), shapeBottom: UIColor(70, 120, 222)),
        Palette(id: 7, top: UIColor(150, 170, 236), bottom: UIColor(212, 236, 251),
                shapeTop: UIColor(214, 246, 255), shapeBottom: UIColor(100, 108, 220)),
        Palette(id: 8, top: UIColor(90, 160, 212), bottom: UIColor(204, 232, 242),
                shapeTop: UIColor(232, 251, 255), shapeBottom: UIColor(76, 138, 200)),
        // Amber Çölü
        Palette(id: 9, top: UIColor(240, 150, 92), bottom: UIColor(252, 222, 152),
                shapeTop: UIColor(255, 236, 172), shapeBottom: UIColor(214, 92, 68)),
        Palette(id: 10, top: UIColor(222, 120, 112), bottom: UIColor(250, 202, 142),
                shapeTop: UIColor(255, 232, 192), shapeBottom: UIColor(184, 78, 96)),
        Palette(id: 11, top: UIColor(202, 142, 92), bottom: UIColor(246, 218, 172),
                shapeTop: UIColor(255, 244, 202), shapeBottom: UIColor(198, 116, 58)),
        // Zümrüt Ormanı
        Palette(id: 12, top: UIColor(72, 170, 132), bottom: UIColor(202, 236, 172),
                shapeTop: UIColor(204, 255, 222), shapeBottom: UIColor(38, 138, 110)),
        Palette(id: 13, top: UIColor(92, 152, 112), bottom: UIColor(226, 242, 182),
                shapeTop: UIColor(232, 255, 204), shapeBottom: UIColor(60, 148, 92)),
        Palette(id: 14, top: UIColor(62, 142, 152), bottom: UIColor(192, 232, 192),
                shapeTop: UIColor(194, 250, 232), shapeBottom: UIColor(40, 118, 150)),
        // Nova
        Palette(id: 15, top: UIColor(62, 52, 122), bottom: UIColor(172, 102, 172),
                shapeTop: UIColor(255, 204, 232), shapeBottom: UIColor(128, 88, 230)),
        Palette(id: 16, top: UIColor(40, 52, 112), bottom: UIColor(122, 92, 182),
                shapeTop: UIColor(184, 242, 255), shapeBottom: UIColor(108, 98, 232)),
        Palette(id: 17, top: UIColor(82, 42, 112), bottom: UIColor(222, 122, 152),
                shapeTop: UIColor(255, 222, 172), shapeBottom: UIColor(190, 90, 204)),
        // Pamuk Şeker seti
        Palette(id: 18, top: UIColor(244, 136, 192), bottom: UIColor(252, 188, 220),
                shapeTop: UIColor(255, 240, 248), shapeBottom: UIColor(222, 86, 156)),
        Palette(id: 19, top: UIColor(224, 138, 206), bottom: UIColor(196, 176, 250),
                shapeTop: UIColor(255, 236, 250), shapeBottom: UIColor(196, 92, 178)),
        Palette(id: 20, top: UIColor(250, 140, 182), bottom: UIColor(254, 196, 206),
                shapeTop: UIColor(255, 244, 240), shapeBottom: UIColor(226, 92, 140)),
    ]

    /// Ana menü için açık pastel paletler.
    static let pastel: [Palette] = Array(all.prefix(6))

    /// Ana menü / açılış paleti: tema seti seçiliyse setin paleti, değilse açılışa göre pastel.
    static var menu: Palette {
        if let set = ThemeSet.active { return all[set.paletteIDs[0]] }
        return pastel[PlayerProgress.shared.launchIndex % pastel.count]
    }

    /// Sezonun temasından, her 5 bölümde bir yeni palet.
    static func forLevel(_ level: Int) -> Palette {
        let progress = PlayerProgress.shared
        let l = max(0, (level - 1) % Season.levelsPer)
        // Tema seti her şeyin önüne geçer
        if let set = ThemeSet.active {
            return all[set.paletteIDs[(l / 5) % set.paletteIDs.count]]
        }
        // Kullanıcının seçtiği tema her yerde sezon paletinin yerine geçer
        if progress.selectedTheme >= 0, progress.themeUnlocked(progress.selectedTheme) {
            let t = Season.all[progress.selectedTheme]
            return all[t.paletteIDs[(l / 5) % t.paletteIDs.count]]
        }
        let s = Season.of(level: level)
        return all[s.paletteIDs[(l / 5) % s.paletteIDs.count]]
    }
}
