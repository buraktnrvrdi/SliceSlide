import GameKit
import UIKit

/// Game Center: giriş, sıralama puanı ve başarım bildirimi.
/// Kimlikler App Store Connect'te aynı adlarla oluşturulmalıdır.
final class GameCenter: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenter()

    static let leaderboardStars = "sliceslide.leaderboard.totalstars"
    static let leaderboardLevel = "sliceslide.leaderboard.highestlevel"
    static let leaderboardFlow = "sliceslide.leaderboard.flowscore"
    static func achievementID(_ id: String) -> String { "sliceslide.ach.\(id)" }

    @Published var isAuthenticated = false
    @Published var message: String?

    private var pending: [String] = []

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, _ in
            DispatchQueue.main.async {
                if let vc, let root = Self.topController() { root.present(vc, animated: true) }
                let ok = GKLocalPlayer.local.isAuthenticated
                self?.isAuthenticated = ok
                if ok, let self {
                    self.pending.forEach { self.send(achievement: $0) }
                    self.pending.removeAll()
                }
            }
        }
    }

    func submit(totalStars: Int, highestLevel: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(totalStars, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardStars]) { _ in }
        GKLeaderboard.submitScore(highestLevel, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardLevel]) { _ in }
    }

    func submitFlow(score: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardFlow]) { _ in }
    }

    func report(achievement id: String) {
        if isAuthenticated { send(achievement: id) } else { pending.append(id) }
    }

    private func send(achievement id: String) {
        let a = GKAchievement(identifier: Self.achievementID(id))
        a.percentComplete = 100
        a.showsCompletionBanner = false
        GKAchievement.report([a]) { _ in }
    }

    func showDashboard() {
        guard isAuthenticated, let root = Self.topController() else {
            message = L("Game Center'a giriş yapılmamış. Cihazın Ayarlar > Game Center bölümünden giriş yapıp tekrar dene.")
            return
        }
        let vc = GKGameCenterViewController(state: .dashboard)
        vc.gameCenterDelegate = self
        root.present(vc, animated: true)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }

    private static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}
