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

    @Published var screen: Screen = AppModel.startScreen
    @Published var showChest = false
    @Published var showIntro = !UserDefaults.standard.bool(forKey: "seenIntro")

    #if DEBUG
    /// Test derlemesinde `-demo` ya da `-noGC`: Game Center girişi ve başarım bildirimi kapalı (ekran görüntüleri için).
    static let quiet = ProcessInfo.processInfo.arguments.contains("-demo") || ProcessInfo.processInfo.arguments.contains("-noGC")
    #endif

    /// Test derlemesinde `-demoStart flow|daily|map|<bölüm>` ile doğrudan o ekrandan başla.
    private static var startScreen: Screen {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-demoStart"), i + 1 < args.count {
            switch args[i + 1] {
            case "flow": return .flow
            case "daily": return .daily
            case "map": return .map
            default: if let n = Int(args[i + 1]) { return .game(n) }
            }
        }
        #endif
        return .home
    }

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
        #if DEBUG
        // Demo kayıtlarında Game Center giriş penceresi çıkmasın
        if !AppModel.quiet { GameCenter.shared.authenticate() }
        #else
        GameCenter.shared.authenticate()
        #endif
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
            #if DEBUG
            if !AppModel.quiet { AchievementToast().zIndex(20) }
            #else
            AchievementToast().zIndex(20)
            #endif
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
