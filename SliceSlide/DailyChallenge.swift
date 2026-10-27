import Foundation

/// Günlük meydan okuma: her gün tüm oyuncular için tek, tarihe bağlı bir bölüm.
enum DailyChallenge {
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { fmt.string(from: date) }

    static func yesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    /// Bugünün bölüm numarası: açık bölümlerin üst yarısından, gün boyunca sabit.
    static func level(unlocked: Int) -> Int {
        let ud = UserDefaults.standard
        let k = key(Date())
        if ud.string(forKey: "dailyKey") == k, ud.integer(forKey: "dailyLevel") > 0 {
            return ud.integer(forKey: "dailyLevel")
        }
        var h: UInt64 = 5381
        for b in k.utf8 { h = h &* 33 &+ UInt64(b) }
        let cap = max(10, unlocked)
        let lo = max(6, cap / 2)
        let n = lo + Int(h % UInt64(cap - lo + 1))
        ud.set(k, forKey: "dailyKey")
        ud.set(n, forKey: "dailyLevel")
        return n
    }
}
