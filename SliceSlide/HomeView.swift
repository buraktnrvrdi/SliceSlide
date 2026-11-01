import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var progress = PlayerProgress.shared
    @ObservedObject private var gc = GameCenter.shared
    @State private var appeared = false
    @State private var chestPulse = false
    @State private var info: String?

    private var palette: Palette { Palette.menu }
    private var season: Season { Season.of(level: progress.unlocked) }

    var body: some View {
        ZStack {
            PaletteBackground(palette: palette)

            VStack(spacing: 14) {
                topBar

                Hero3DView(top: palette.shapeTop, bottom: palette.shapeBottom)
                    .frame(minHeight: 170, maxHeight: .infinity)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)

                wordmark

                seasonCard

                PillButton(title: L("Oyna"), width: 280, tint: palette.shapeBottomColor) { model.go(.map) }

                HStack(spacing: 10) {
                    dailyCard
                    flowCard
                }

                dock
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .alert(L("Günlük Sandık"), isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
            Button(L("Tamam"), role: .cancel) {}
        } message: { Text(info ?? "") }
        .alert("Game Center", isPresented: Binding(get: { gc.message != nil }, set: { if !$0 { gc.message = nil } })) {
            Button(L("Tamam"), role: .cancel) {}
        } message: { Text(gc.message ?? "") }
        .onAppear {
            Music.shared.play(season: season.index)
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.05)) { appeared = true }
            chestPulse = true
        }
    }

    // MARK: Üst çubuk

    private var topBar: some View {
        HStack(spacing: 8) {
            chip("lightbulb.fill", "\(progress.hints)", tint: Color(red: 1, green: 0.92, blue: 0.55))
            chip("shield.lefthalf.filled", "\(progress.shields)", tint: Color(red: 0.75, green: 0.9, blue: 1))
            Spacer()
            CircleIconButton(systemName: "gearshape.fill", size: 42) { model.go(.settings) }
        }
        .padding(.top, 4)
    }

    private func chip(_ icon: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(tint)
            Text(value).font(.custom("AvenirNext-Medium", size: 15)).monospacedDigit().foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.2)))
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
    }

    // MARK: Logo

    private var wordmark: some View {
        HStack(spacing: 10) {
            Text("SLICE").font(.custom("AvenirNext-Medium", size: 34))
            Text("&").font(.custom("AvenirNext-UltraLight", size: 34))
            Text("SLIDE").font(.custom("AvenirNext-Regular", size: 34))
        }
        .kerning(5)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
        .shadow(color: .white.opacity(0.7), radius: 14)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    // MARK: Sezon kartı

    private var seasonCard: some View {
        let done = (1...Season.levelsPer).filter { progress.stars[season.index * Season.levelsPer + $0] != nil }.count
        let frac = CGFloat(done) / CGFloat(Season.levelsPer)
        return HStack(spacing: 12) {
            GemView(top: season.gemTopColor, bottom: season.gemBottomColor, size: 44)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("SEZON %lld", season.number))
                            .font(.custom("AvenirNext-Medium", size: 10)).kerning(2.5).opacity(0.85)
                        Text(season.name).font(.custom("AvenirNext-Medium", size: 16))
                    }
                    Spacer()
                    Text("Level \(progress.unlocked)")
                        .font(.custom("AvenirNext-Medium", size: 13)).opacity(0.95)
                }
                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule()
                            .fill(LinearGradient(colors: [season.gemTopColor, season.gemBottomColor], startPoint: .leading, endPoint: .trailing))
                            .scaleEffect(x: max(frac, 0.05), y: 1, anchor: .leading)
                            .shadow(color: season.gemTopColor.opacity(0.9), radius: 5)
                        Capsule().stroke(.white.opacity(0.6), lineWidth: 1)
                    }
                    .frame(height: 8)
                    Text("\(done)/\(Season.levelsPer)")
                        .font(.custom("AvenirNext-Medium", size: 12)).monospacedDigit().opacity(0.9)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white.opacity(0.2)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.5), lineWidth: 1))
    }

    // MARK: Mod kartları

    private var dailyCard: some View {
        modeCard(icon: progress.dailyDone ? "checkmark.seal.fill" : "calendar",
                 title: L("Günlük"),
                 sub: "🔥 \(progress.currentStreak) · \(progress.dailyDone ? L("Tamam (durum)") : L("Hazır"))") {
            model.go(.daily)
        }
    }

    private var flowCard: some View {
        modeCard(icon: "bolt.horizontal.fill", title: L("Akış"),
                 sub: progress.bestFlow > 0 ? L("En iyi %lld", progress.bestFlow) : L("60 sn · Skor")) {
            model.go(.flow)
        }
    }

    private func modeCard(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button {
            SFX.shared.play(.tap)
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.25)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.custom("AvenirNext-Medium", size: 16)).lineLimit(1)
                    Text(sub).font(.custom("AvenirNext-Regular", size: 12)).lineLimit(1).minimumScaleFactor(0.8).opacity(0.92)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.2)))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: Dock

    private var dock: some View {
        HStack(spacing: 0) {
            dockItem("trophy.fill", L("Başarım")) { model.go(.achievements) }
            dockItem("sparkles", L("Kişisel")) { model.go(.collection) }
            chestItem
            dockItem("chart.bar.fill", L("Sıralama")) { gc.showDashboard() }
        }
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
        .background(Capsule().fill(.white.opacity(0.12)))
        .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    private func dockItem(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            SFX.shared.play(.tap)
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.custom("AvenirNext-Medium", size: 10))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
    }

    private var chestItem: some View {
        let ready = progress.chestReady
        return Button {
            SFX.shared.play(.tap)
            Haptics.tap()
            if ready { withAnimation(.easeInOut(duration: 0.3)) { model.showChest = true } }
            else { info = L("Günlük sandığı bugün açtın. Yarın yenisi seni bekliyor!") }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: ready ? "gift.fill" : "gift").font(.system(size: 20))
                    .foregroundStyle(ready ? Color(red: 1, green: 0.9, blue: 0.5) : .white.opacity(0.8))
                    .shadow(color: Color(red: 1, green: 0.85, blue: 0.4).opacity(ready ? 0.95 : 0), radius: chestPulse ? 10 : 3)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: chestPulse)
                    .overlay(alignment: .topTrailing) {
                        if ready {
                            Circle().fill(Color(red: 1, green: 0.35, blue: 0.4)).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 1.2)).offset(x: 6, y: -4)
                        }
                    }
                Text(L("Sandık")).font(.custom("AvenirNext-Medium", size: 10))
                    .foregroundStyle(.white.opacity(ready ? 1 : 0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
    }
}
