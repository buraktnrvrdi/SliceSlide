import Foundation
import UserNotifications

/// Yerel bildirimler: akşam seri hatırlatması ve öğlen sandık hatırlatması.
enum Reminders {
    private static let prefix = "sliceslide."
    private static var center: UNUserNotificationCenter { .current() }

    /// İzin henüz sorulmadıysa nazikçe iste (ilk günlük bölüm ya da ilk sandıktan sonra).
    static func requestIfNeeded() {
        guard Prefs.notifyOn else { return }
        center.getNotificationSettings { s in
            guard s.authorizationStatus == .notDetermined else { reschedule(); return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                if granted { reschedule() }
            }
        }
    }

    /// Önümüzdeki 3 günün hatırlatmalarını yeniden kurar.
    static func reschedule() {
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) })
            guard Prefs.notifyOn else { return }
            center.getNotificationSettings { s in
                guard s.authorizationStatus == .authorized || s.authorizationStatus == .provisional else { return }
                DispatchQueue.main.async { schedule() }
            }
        }
    }

    private static func schedule() {
        let progress = PlayerProgress.shared
        let cal = Calendar.current
        let now = Date()
        let streak = progress.currentStreak
        for offset in 0...2 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }

            // Akşam 19:00: seri / günlük meydan okuma
            if !(offset == 0 && progress.dailyDone),
               let at = cal.date(bySettingHour: 19, minute: 0, second: 0, of: day), at > now {
                let body: String
                if streak > 0 && offset <= 1 {
                    body = "🔥 \(streak) günlük serin bozulmasın! Bugünün meydan okuması seni bekliyor."
                } else {
                    body = "Günlük meydan okuma hazır. 60 saniyelik Akış modunda rekorunu da kırabilirsin."
                }
                add(id: "daily.\(offset)", title: "Slice & Slide", body: body, at: at)
            }

            // Öğlen 12:30: günlük sandık
            if !(offset == 0 && !progress.chestReady),
               let at = cal.date(bySettingHour: 12, minute: 30, second: 0, of: day), at > now {
                add(id: "chest.\(offset)", title: "Günlük Sandık 🎁", body: "Bugünün sürpriz ödülü seni bekliyor. Aç ve ipucu ya da Seri Kalkanı kazan!", at: at)
            }
        }
    }

    private static func add(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger))
    }

    static func cancelAll() {
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) })
        }
    }
}
