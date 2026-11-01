import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let goal: Int
    let value: (PlayerProgress) -> Int

    static let all: [Achievement] = [
        Achievement(id: "first", title: L("İlk Kesim"), detail: L("İlk bölümü tamamla"), icon: "scissors", goal: 1) { $0.completedCount },
        Achievement(id: "levels10", title: L("Çırak"), detail: L("10 bölüm tamamla"), icon: "10.circle.fill", goal: 10) { $0.completedCount },
        Achievement(id: "levels50", title: L("Usta Kesici"), detail: L("50 bölüm tamamla"), icon: "flame.fill", goal: 50) { $0.completedCount },
        Achievement(id: "levels150", title: L("Efsane"), detail: L("150 bölüm tamamla"), icon: "crown.fill", goal: 150) { $0.completedCount },
        Achievement(id: "levels300", title: L("Son Kesim"), detail: L("Tüm 300 bölümü tamamla"), icon: "infinity", goal: 300) { $0.completedCount },
        Achievement(id: "stars50", title: L("Yıldız Avcısı"), detail: L("Toplam 50 yıldız topla"), icon: "star.fill", goal: 50) { $0.totalStars },
        Achievement(id: "stars300", title: L("Yıldız Koleksiyoncusu"), detail: L("Toplam 300 yıldız topla"), icon: "star.circle.fill", goal: 300) { $0.totalStars },
        Achievement(id: "perfect5", title: L("Kusursuz"), detail: L("5 bölümü yüzde 1'den az sapmayla geç"), icon: "target", goal: 5) { $0.perfects },
        Achievement(id: "cuts100", title: L("Keskin"), detail: L("100 kesim yap"), icon: "bolt.fill", goal: 100) { $0.totalCuts },
        Achievement(id: "cuts1000", title: L("Kristal Kasabı"), detail: L("1000 kesim yap"), icon: "bolt.circle.fill", goal: 1000) { $0.totalCuts },
        Achievement(id: "season1", title: L("Sezon Fatihi"), detail: L("İlk sezonu bitir"), icon: "diamond.fill", goal: 1) { $0.seasonsDone },
        Achievement(id: "season5", title: L("Nova Efendisi"), detail: L("5 sezonu da bitir"), icon: "sparkles", goal: 5) { $0.seasonsDone },
        Achievement(id: "flow1000", title: L("Akışta"), detail: L("Akış modunda 1000 puana ulaş"), icon: "bolt.horizontal.fill", goal: 1000) { $0.bestFlow },
        Achievement(id: "flow4000", title: L("Akış Ustası"), detail: L("Akış modunda 4000 puana ulaş"), icon: "waveform.path", goal: 4000) { $0.bestFlow },
        Achievement(id: "daily1", title: L("Günün Kahramanı"), detail: L("İlk günlük meydan okumayı tamamla"), icon: "calendar", goal: 1) { $0.dailyWins },
        Achievement(id: "streak3", title: L("Alışkanlık"), detail: L("3 gün üst üste günlük meydan okuma"), icon: "3.circle.fill", goal: 3) { $0.bestStreak },
        Achievement(id: "streak7", title: L("Haftalık Seri"), detail: L("7 gün üst üste"), icon: "flame.circle.fill", goal: 7) { $0.bestStreak },
        Achievement(id: "streak30", title: L("Ay Efendisi"), detail: L("30 gün üst üste"), icon: "moon.stars.fill", goal: 30) { $0.bestStreak },
    ]
}
