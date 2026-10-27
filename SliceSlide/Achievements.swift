import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let goal: Int
    let value: (PlayerProgress) -> Int

    static let all: [Achievement] = [
        Achievement(id: "first", title: "İlk Kesim", detail: "İlk bölümü tamamla", icon: "scissors", goal: 1) { $0.completedCount },
        Achievement(id: "levels10", title: "Çırak", detail: "10 bölüm tamamla", icon: "10.circle.fill", goal: 10) { $0.completedCount },
        Achievement(id: "levels50", title: "Usta Kesici", detail: "50 bölüm tamamla", icon: "flame.fill", goal: 50) { $0.completedCount },
        Achievement(id: "levels150", title: "Efsane", detail: "150 bölüm tamamla", icon: "crown.fill", goal: 150) { $0.completedCount },
        Achievement(id: "levels300", title: "Son Kesim", detail: "Tüm 300 bölümü tamamla", icon: "infinity", goal: 300) { $0.completedCount },
        Achievement(id: "stars50", title: "Yıldız Avcısı", detail: "Toplam 50 yıldız topla", icon: "star.fill", goal: 50) { $0.totalStars },
        Achievement(id: "stars300", title: "Yıldız Koleksiyoncusu", detail: "Toplam 300 yıldız topla", icon: "star.circle.fill", goal: 300) { $0.totalStars },
        Achievement(id: "perfect5", title: "Kusursuz", detail: "5 bölümü %1'den az sapmayla geç", icon: "target", goal: 5) { $0.perfects },
        Achievement(id: "cuts100", title: "Keskin", detail: "100 kesim yap", icon: "bolt.fill", goal: 100) { $0.totalCuts },
        Achievement(id: "cuts1000", title: "Kristal Kasabı", detail: "1000 kesim yap", icon: "bolt.circle.fill", goal: 1000) { $0.totalCuts },
        Achievement(id: "season1", title: "Sezon Fatihi", detail: "İlk sezonu bitir", icon: "diamond.fill", goal: 1) { $0.seasonsDone },
        Achievement(id: "season5", title: "Nova Efendisi", detail: "5 sezonu da bitir", icon: "sparkles", goal: 5) { $0.seasonsDone },
        Achievement(id: "flow1000", title: "Akışta", detail: "Akış modunda 1000 puana ulaş", icon: "bolt.horizontal.fill", goal: 1000) { $0.bestFlow },
        Achievement(id: "flow4000", title: "Akış Ustası", detail: "Akış modunda 4000 puana ulaş", icon: "waveform.path", goal: 4000) { $0.bestFlow },
        Achievement(id: "daily1", title: "Günün Kahramanı", detail: "İlk günlük meydan okumayı tamamla", icon: "calendar", goal: 1) { $0.dailyWins },
        Achievement(id: "streak3", title: "Alışkanlık", detail: "3 gün üst üste günlük meydan okuma", icon: "3.circle.fill", goal: 3) { $0.bestStreak },
        Achievement(id: "streak7", title: "Haftalık Seri", detail: "7 gün üst üste", icon: "flame.circle.fill", goal: 7) { $0.bestStreak },
        Achievement(id: "streak30", title: "Ay Efendisi", detail: "30 gün üst üste", icon: "moon.stars.fill", goal: 30) { $0.bestStreak },
    ]
}
