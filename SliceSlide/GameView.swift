import SwiftUI
import SpriteKit

struct GameView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var session: GameSession
    @ObservedObject private var progress = PlayerProgress.shared
    @State private var introSeason: Season?

    init(level: Int, mode: GameSession.Mode = .level) {
        _session = StateObject(wrappedValue: GameSession(level: level, mode: mode))
    }

    var body: some View {
        ZStack {
            PaletteBackground(palette: session.palette, intensity: Double(min(session.combo, 6)))
                .id(session.palette.id)
                .transition(.opacity)

            SpriteView(scene: session.scene, options: [.allowsTransparency])
                .ignoresSafeArea()

            hud

            if session.level <= 5, session.mode == .level, session.phase == .playing, session.cutsLeft == session.totalCuts {
                Text(L("Parmağını sürükleyerek kes"))
                    .font(.custom("AvenirNext-Regular", size: 17))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .frame(maxHeight: .infinity)
                    .padding(.top, 60)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            overlays

            if let t = session.toast {
                Text(t)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 90)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }

            if session.flowOver { flowOverView }

            if let season = introSeason { seasonIntro(season) }
        }
        .onAppear { checkIntro(); Music.shared.play(season: musicIndex) }
        .onDisappear { Music.shared.setIntensity(0) }
        .onChange(of: session.combo) { _, c in Music.shared.setIntensity(c) }
        .onChange(of: session.level) { _, _ in
            checkIntro()
            Music.shared.play(season: musicIndex)
        }
        .animation(.easeInOut(duration: 1.0), value: session.palette.id)
        .animation(.easeInOut(duration: 0.3), value: session.cutsLeft)
        .animation(.easeInOut(duration: 0.25), value: session.toast)
        .animation(.easeInOut(duration: 0.3), value: session.flowOver)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: session.phase)
    }

    private var musicIndex: Int { session.mode == .flow ? 5 : Season.of(level: session.level).index }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 12) {
            ZStack {
                Text(session.mode == .flow ? L("Akış") : (session.daily ? L("Günlük") : "Level \(session.level)"))
                    .font(.custom("AvenirNext-Regular", size: 40))
                    .kerning(3)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 1)
                    .shadow(color: .white.opacity(0.4), radius: 8)
                HStack {
                    hintButton
                    Spacer()
                    Button {
                        SFX.shared.play(.tap)
                        Haptics.tap()
                        session.pause()
                    } label: {
                        HStack(spacing: 5) {
                            Capsule().frame(width: 6, height: 26)
                            Capsule().frame(width: 6, height: 26)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(.horizontal, 22)

            cutsIndicator

            if session.mode == .flow { flowInfo.padding(.top, 6) }

            Spacer()

            if session.mode == .flow { Color.clear.frame(height: 11) } else if session.daily { dailyBadge } else { progressDots }
        }
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var hintButton: some View {
        Button {
            Haptics.tap()
            session.requestHint()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.5))
                    .shadow(color: .white.opacity(0.5), radius: 6)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.2)))
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.2))
                Text("\(progress.hints)")
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundStyle(session.palette.shapeBottomColor)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(.white))
                    .offset(x: 4, y: -4)
            }
            .opacity(session.mode == .flow ? 0 : (session.phase == .playing ? 1 : 0.4))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(session.mode == .flow)
    }

    private var flowInfo: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(session.score)")
                    .font(.custom("AvenirNext-Medium", size: 34))
                    .monospacedDigit()
                Text(L("puan")).font(.custom("AvenirNext-Regular", size: 14)).opacity(0.85)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25)).frame(width: 220, height: 7)
                Capsule()
                    .fill(session.timeLeft < 10 ? Color(red: 1, green: 0.5, blue: 0.55) : .white)
                    .frame(width: 220 * CGFloat(max(0, min(1, session.timeLeft / 60))), height: 7)
            }
            Text(L("%lld sn", Int(ceil(max(0, session.timeLeft)))))
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var dailyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
            Text(L("Günlük meydan okuma · Seri %lld", progress.currentStreak))
        }
        .font(.custom("AvenirNext-Medium", size: 15))
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.2)))
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
    }

    private var cutsIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "scissors")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
            ForEach(0..<max(session.totalCuts, 1), id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i < session.cutsLeft ? 0.95 : 0.25))
                    .frame(width: 22, height: 5)
            }
            if session.combo >= 2 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("x\(session.combo)")
                }
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.5))
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.2)))
                .transition(.scale.combined(with: .opacity))
                .padding(.leading, 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: session.combo)
    }

    private var progressDots: some View {
        let cur = (session.level - 1) % 10
        return HStack(spacing: 14) {
            ForEach(0..<10, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i == cur ? 1 : (i < cur ? 0.8 : 0.3)))
                    .frame(width: i == cur ? 40 : 11, height: 11)
            }
        }
    }

    // MARK: Overlay'ler

    @ViewBuilder private var overlays: some View {
        switch session.phase {
        case .playing:
            EmptyView()

        case .paused:
            ZStack {
                Color.black.opacity(0.28).ignoresSafeArea()
                    .contentShape(Rectangle())
                VStack(spacing: 18) {
                    Text(L("Durduruldu"))
                        .font(.custom("AvenirNext-UltraLight", size: 34))
                        .kerning(3)
                        .foregroundStyle(.white)
                        .padding(.bottom, 10)
                    AudioToggles().padding(.bottom, 6)
                    PillButton(title: L("Devam Et"), tint: session.palette.shapeBottomColor) { session.resume() }
                    PillButton(title: L("Tekrar"), tint: session.palette.shapeBottomColor) { if session.mode == .flow { session.restartFlow() } else { session.restart() } }
                    PillButton(title: session.mode == .level ? L("Bölümler") : L("Ana Menü"), tint: session.palette.shapeBottomColor) { model.go(session.mode == .level ? .map : .home) }
                }
            }
            .transition(.opacity)

        case .won where session.mode == .flow:
            EmptyView()

        case .lost where session.mode == .flow:
            EmptyView()

        case .won(let stars) where session.daily:
            dailyWin(stars: stars)

        case .won where session.level % Season.levelsPer == 0:
            seasonReward(Season.of(level: session.level))

        case .won(let stars):
            VStack(spacing: 26) {
                StarsRow(count: stars)
                Text(L("Harika!"))
                    .font(.custom("AvenirNext-UltraLight", size: 38))
                    .kerning(3)
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.6), radius: 10)
                HStack(spacing: 22) {
                    CircleIconButton(systemName: "arrow.counterclockwise", size: 58) { session.restart() }
                    CircleIconButton(systemName: "arrow.right", size: 78, filled: true,
                                     tint: session.palette.shapeBottomColor) {
                        if session.level >= LevelFactory.totalLevels { model.go(.map) } else { session.next() }
                    }
                    CircleIconButton(systemName: "square.grid.2x2", size: 58) { model.go(.map) }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 120)
            .transition(.scale(scale: 0.85).combined(with: .opacity))

        case .lost(let message, _):
            VStack(spacing: 22) {
                Text(message)
                    .font(.custom("AvenirNext-Regular", size: 22))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.12), radius: 6)
                PillButton(title: L("Tekrar Dene"), tint: session.palette.shapeBottomColor) { session.restart() }
            }
            .padding(.horizontal, 30)
            .frame(maxHeight: .infinity)
            .padding(.bottom, 120)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    // MARK: Akış modu

    private var flowOverView: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().contentShape(Rectangle())
            VStack(spacing: 16) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.8), radius: 10)
                Text(session.newBest ? L("Yeni Rekor!") : L("Süre Doldu"))
                    .font(.custom("AvenirNext-UltraLight", size: 38))
                    .foregroundStyle(.white)
                Text("\(session.score)")
                    .font(.custom("AvenirNext-Medium", size: 64))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.6), radius: 14)
                Text(L("En iyi: %lld", progress.bestFlow))
                    .font(.custom("AvenirNext-Regular", size: 17))
                    .foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 18) {
                    CircleIconButton(systemName: "house.fill", size: 58) { model.go(.home) }
                    CircleIconButton(systemName: "arrow.counterclockwise", size: 78, filled: true, tint: session.palette.shapeBottomColor) {
                        session.restartFlow()
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 30).padding(.horizontal, 36)
            .background(RoundedRectangle(cornerRadius: 34).fill(session.palette.shapeBottomColor.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: 34).stroke(.white.opacity(0.6), lineWidth: 1.2))
        }
        .transition(.opacity)
    }

    // MARK: Günlük

    private func dailyWin(stars: Int) -> some View {
        VStack(spacing: 20) {
            StarsRow(count: stars)
            Text(L("Günlük tamamlandı!"))
                .font(.custom("AvenirNext-UltraLight", size: 34))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.6), radius: 10)
            if let r = session.dailyReward {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                        Text(L("%lld. gün seri", r.streak))
                    }
                    .font(.custom("AvenirNext-Medium", size: 20))
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                        Text(L("+%lld ipucu hakkı", r.reward))
                    }
                    .font(.custom("AvenirNext-Regular", size: 17))
                    if r.shield { Label(L("Seri Kalkanı seni kurtardı"), systemImage: "shield.fill").font(.custom("AvenirNext-Regular", size: 14)) }
                    if r.streak % 7 == 0 { Text(L("Haftalık seri bonusu!")).font(.custom("AvenirNext-Regular", size: 14)) }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.2)))
            } else {
                Text(L("Bugünün ödülünü zaten aldın. Yarın yeni bir bölüm seni bekliyor."))
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 30)
            }
            HStack(spacing: 22) {
                CircleIconButton(systemName: "arrow.counterclockwise", size: 58) { session.restart() }
                CircleIconButton(systemName: "house.fill", size: 78, filled: true, tint: session.palette.shapeBottomColor) { model.go(.home) }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, 100)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    // MARK: Sezon

    private func checkIntro() {
        guard !session.daily else { return }
        let lvl = session.level
        guard (lvl - 1) % Season.levelsPer == 0 else { return }
        let key = "seasonIntro_\(Season.of(level: lvl).index)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        withAnimation(.easeInOut(duration: 0.35)) { introSeason = Season.of(level: lvl) }
    }

    private func seasonIntro(_ season: Season) -> some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea().contentShape(Rectangle())
            VStack(spacing: 16) {
                Image(systemName: season.icon)
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.7), radius: 10)
                Text(L("SEZON %lld", season.number))
                    .font(.custom("AvenirNext-Medium", size: 14)).kerning(4)
                    .foregroundStyle(.white.opacity(0.9))
                Text(season.name)
                    .font(.custom("AvenirNext-UltraLight", size: 40))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(season.mechanic)
                    .font(.custom("AvenirNext-Regular", size: 17))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 6)
                HStack(spacing: 8) {
                    GemView(top: season.gemTopColor, bottom: season.gemBottomColor, size: 30)
                    Text(L("Sezon sonu ödülü: %@", season.rewardName))
                        .font(.custom("AvenirNext-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.95))
                }
                PillButton(title: L("Başla"), width: 200, tint: season.gemBottomColor) {
                    UserDefaults.standard.set(true, forKey: "seasonIntro_\(season.index)")
                    withAnimation(.easeInOut(duration: 0.3)) { introSeason = nil }
                }
                .padding(.top, 6)
            }
            .padding(.vertical, 30).padding(.horizontal, 26)
            .background(RoundedRectangle(cornerRadius: 34).fill(.ultraThinMaterial).opacity(0.5))
            .background(RoundedRectangle(cornerRadius: 34).fill(season.gemBottomColor.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 34).stroke(.white.opacity(0.6), lineWidth: 1.2))
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    private func seasonReward(_ season: Season) -> some View {
        let isLast = season.index == Season.all.count - 1
        let stars = PlayerProgress.shared.starsIn(season: season.index)
        return ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().contentShape(Rectangle())
            VStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.8), radius: 10)
                Text(isLast ? L("Oyunu Tamamladın!") : L("Sezon %lld Tamamlandı!", season.number))
                    .font(.custom("AvenirNext-UltraLight", size: 34))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                GemView(top: season.gemTopColor, bottom: season.gemBottomColor, size: 130)
                    .padding(.vertical, 6)
                Text(L("Ödül: %@", season.rewardName))
                    .font(.custom("AvenirNext-Medium", size: 20))
                    .foregroundStyle(.white)
                Text(isLast ? L("Beş sezonu da bitirdin. Tüm kristaller koleksiyonunda; istediğini seçip bölümleri yeniden oynayabilirsin.")
                            : L("Kristal koleksiyonuna eklendi. Koleksiyondan seçip oyunda kullanabilirsin."))
                    .font(.custom("AvenirNext-Regular", size: 15))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.92))
                Text(L("Sezon yıldızı: %lld / %lld", stars, Season.levelsPer * 3))
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 18) {
                    CircleIconButton(systemName: "sparkles", size: 58) { model.go(.collection) }
                    CircleIconButton(systemName: isLast ? "square.grid.2x2" : "arrow.right", size: 78, filled: true,
                                     tint: season.gemBottomColor) {
                        if isLast { model.go(.map) } else { session.next() }
                    }
                    CircleIconButton(systemName: "square.grid.2x2", size: 58) { model.go(.map) }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 28).padding(.horizontal, 24)
            .background(RoundedRectangle(cornerRadius: 34).fill(season.gemBottomColor.opacity(0.38)))
            .overlay(RoundedRectangle(cornerRadius: 34).stroke(.white.opacity(0.6), lineWidth: 1.2))
            .padding(.horizontal, 22)
        }
        .transition(.opacity)
    }
}
