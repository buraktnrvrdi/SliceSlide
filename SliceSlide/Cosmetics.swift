import SwiftUI
import UIKit

/// Kristal skini: sezon ödülleri ve kristal parçalarıyla açılanlar.
struct Skin: Identifiable {
    enum Source { case season(Int), fragments(Int) }   // fragments(k): 7×k parça
    let id: Int
    let name: String
    let colors: [UIColor]
    let source: Source

    var swiftColors: [Color] { colors.map { Color($0) } }

    static let fragmentsPerSkin = 7

    static let all: [Skin] = Season.all.map {
        Skin(id: $0.index, name: $0.rewardName, colors: [$0.gemTop, $0.gemBottom], source: .season($0.index))
    } + [
        Skin(id: 5, name: "Altın", colors: [UIColor(255, 238, 168), UIColor(242, 184, 66), UIColor(192, 112, 32)], source: .fragments(1)),
        Skin(id: 6, name: "Gökkuşağı", colors: [UIColor(255, 134, 192), UIColor(255, 222, 122), UIColor(122, 236, 202), UIColor(132, 132, 255)], source: .fragments(2)),
        Skin(id: 7, name: "Gece", colors: [UIColor(158, 158, 255), UIColor(74, 62, 176), UIColor(30, 30, 100)], source: .fragments(3)),
        Skin(id: 8, name: "Gül Kuvarsı", colors: [UIColor(255, 232, 242), UIColor(246, 162, 198), UIColor(200, 100, 162)], source: .fragments(4)),
        Skin(id: 9, name: "Okyanus", colors: [UIColor(194, 250, 255), UIColor(62, 172, 222), UIColor(30, 82, 172)], source: .fragments(5)),
        Skin(id: 10, name: "Gün Batımı", colors: [UIColor(255, 232, 154), UIColor(255, 142, 102), UIColor(192, 72, 142)], source: .fragments(6)),
    ]
}

/// Kesim izi: kesim çizgisinin ve parçacıkların görünümü.
struct Trail: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let colors: [UIColor]
    let kind: Int          // CutFX parçacık türü
    let gravity: CGFloat
    let line: UIColor

    var swiftColors: [Color] { colors.map { Color($0) } }

    static let all: [Trail] = [
        Trail(id: 0, name: "Sezon İzi", icon: "scissors", colors: [.white], kind: 0, gravity: 0, line: .white),
        Trail(id: 1, name: "Altın", icon: "sparkle", colors: [UIColor(255, 214, 140), UIColor(255, 174, 96), UIColor(255, 238, 190)], kind: 2, gravity: -60, line: UIColor(255, 238, 190)),
        Trail(id: 2, name: "Neon", icon: "bolt.fill", colors: [UIColor(90, 240, 255), UIColor(255, 100, 225), UIColor(255, 240, 130)], kind: 4, gravity: 0, line: UIColor(205, 248, 255)),
        Trail(id: 3, name: "Buz", icon: "snowflake", colors: [UIColor(255, 255, 255), UIColor(190, 235, 255), UIColor(150, 205, 255)], kind: 1, gravity: -20, line: UIColor(225, 247, 255)),
        Trail(id: 4, name: "Gül Kuvarsı", icon: "heart.fill", colors: [UIColor(255, 200, 224), UIColor(246, 150, 194), UIColor(255, 235, 244)], kind: 0, gravity: 0, line: UIColor(255, 226, 240)),
        Trail(id: 5, name: "Gökkuşağı", icon: "rainbow", colors: [UIColor(255, 120, 160), UIColor(255, 214, 110), UIColor(120, 235, 190), UIColor(130, 150, 255)], kind: 4, gravity: 0, line: .white),
        Trail(id: 6, name: "Orman", icon: "leaf.fill", colors: [UIColor(190, 255, 205), UIColor(120, 220, 150), UIColor(230, 255, 190)], kind: 3, gravity: -26, line: UIColor(225, 255, 225)),
    ]
}

/// Sandık nadirlik seviyeleri.
enum ChestTier {
    static let names = ["Normal", "Nadir", "Destansı"]
    /// Kristal renkleri; Normal için sezonun kendi kristali kullanılır.
    static func colors(_ tier: Int, season: Season) -> [Color] {
        switch tier {
        case 1: return [Color(red: 0.76, green: 0.84, blue: 1), Color(red: 0.47, green: 0.43, blue: 0.95), Color(red: 0.27, green: 0.2, blue: 0.68)]
        case 2: return [Color(red: 1, green: 0.95, blue: 0.68), Color(red: 1, green: 0.68, blue: 0.32), Color(red: 0.9, green: 0.35, blue: 0.55)]
        default: return [season.gemTopColor, season.gemBottomColor]
        }
    }
}

struct ChestItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case hints(Int)
        case shield(Int)
        case fragments(Int)
        case trail(Int)
        case theme(Int)
        case skin(Int)     // parçalarla yeni açılan kristal
    }
    let id = UUID()
    let kind: Kind
}

struct ChestResult {
    let tier: Int
    let jackpot: Bool
    let items: [ChestItem]
}
