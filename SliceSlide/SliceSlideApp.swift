import SwiftUI

final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case home
        case map
        case game(Int)
        case collection
        case achievements
        case daily
        case flow
        case settings
    }

    @Published var screen: Screen = .home
    @Published var showChest = false
    @Published var showIntro = !UserDefaults.standard.bool(forKey: "seenIntro")

    func go(_ s: Screen) {
        withAnimation(.easeInOut(duration: 0.35)) { screen = s }
    }
}

@main
struct SliceSlideApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Haptics.prepare()
        _ = SFX.shared
        GameCenter.shared.authenticate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .statusBarHidden(true)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, p in if p == .active { Reminders.reschedule() } }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var ads = AdService.shared

    var body: some View {
        ZStack {
            switch model.screen {
            case .home:
                HomeView().transition(.opacity)
            case .map:
                LevelMapView().transition(.opacity)
            case .collection:
                CollectionView().transition(.opacity)
            case .achievements:
                AchievementsView().transition(.opacity)
            case .daily:
                GameView(level: DailyChallenge.level(unlocked: PlayerProgress.shared.unlocked), mode: .daily)
                    .transition(.opacity)
            case .flow:
                GameView(level: 2, mode: .flow).transition(.opacity)
            case .settings:
                SettingsView().transition(.opacity)
            case .game(let level):
                GameView(level: level).transition(.opacity)
            }
            if model.showChest { ChestView().transition(.opacity).zIndex(15) }
            AchievementToast().zIndex(20)
            #if DEBUG
            if ads.presenting { MockAdView().transition(.opacity).zIndex(30) }
            #endif
            if model.showIntro {
                IntroView(palette: Palette.menu) {
                    withAnimation(.easeInOut(duration: 0.35)) { model.showIntro = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}
