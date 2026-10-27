import SwiftUI

struct LevelMapView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var progress = PlayerProgress.shared

    private let rowHeight: CGFloat = 104

    private func xOffset(_ level: Int) -> CGFloat { CGFloat(sin(Double(level) * 0.85)) * 72 }

    var body: some View {
        ZStack(alignment: .top) {
            PaletteBackground(palette: Palette.forLevel(progress.unlocked))

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach((1...LevelFactory.totalLevels).reversed(), id: \.self) { level in
                            row(level).id(level)
                            if (level - 1) % Season.levelsPer == 0 {
                                banner(Season.of(level: level))
                            }
                        }
                    }
                    .padding(.top, 130)
                    .padding(.bottom, 90)
                }
                .onAppear {
                    Music.shared.play(season: Season.of(level: progress.unlocked).index)
                    DispatchQueue.main.async { proxy.scrollTo(progress.unlocked, anchor: .center) }
                }
            }

            HStack {
                CircleIconButton(systemName: "chevron.left", size: 46) { model.go(.home) }
                Spacer()
                Text("Bölümler")
                    .font(.custom("AvenirNext-Medium", size: 28))
                    .kerning(2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                Spacer()
                CircleIconButton(systemName: "sparkles", size: 46) { model.go(.collection) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .background(
                LinearGradient(colors: [Palette.forLevel(progress.unlocked).topColor, .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
    }

    private func row(_ level: Int) -> some View {
        let unlocked = level <= progress.unlocked
        let current = level == progress.unlocked
        return ZStack {
            GeometryReader { g in
                if (level - 1) % Season.levelsPer != 0 {
                    Path { p in
                        let x0 = g.size.width / 2 + xOffset(level)
                        let x1 = g.size.width / 2 + xOffset(level - 1)
                        p.move(to: CGPoint(x: x0, y: rowHeight / 2))
                        p.addCurve(to: CGPoint(x: x1, y: rowHeight * 1.5),
                                   control1: CGPoint(x: x0, y: rowHeight),
                                   control2: CGPoint(x: x1, y: rowHeight))
                    }
                    .stroke(.white.opacity(level <= progress.unlocked ? 0.65 : 0.3),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 9]))
                }
            }

            Button {
                if unlocked {
                    SFX.shared.play(.tap)
                    Haptics.tap()
                    model.go(.game(level))
                } else {
                    SFX.shared.play(.deny)
                    Haptics.warning()
                }
            } label: {
                ZStack {
                    Circle().fill(.white.opacity(unlocked ? 0.30 : 0.12))
                    Circle().stroke(.white.opacity(current ? 1 : (unlocked ? 0.6 : 0.3)), lineWidth: current ? 3 : 1.5)
                    if unlocked {
                        Text("\(level)")
                            .font(.custom("AvenirNext-Regular", size: 24))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(width: 66, height: 66)
                .shadow(color: .white.opacity(current ? 0.9 : 0), radius: 16)
                .overlay(alignment: .topTrailing) {
                    if level % Season.levelsPer == 0 {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(Season.of(level: level).gemBottomColor.opacity(0.9)))
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
                            .offset(x: 8, y: -8)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let s = progress.stars[level], s > 0 {
                        HStack(spacing: 1) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: "star.fill").font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(i < s ? 1 : 0.3))
                            }
                        }
                        .offset(y: 16)
                    }
                }
            }
            .buttonStyle(PressScaleStyle())
            .offset(x: xOffset(level))
        }
        .frame(height: rowHeight)
    }

    private func banner(_ season: Season) -> some View {
        let locked = season.firstLevel > progress.unlocked
        let done = progress.seasonDone(season.index)
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: locked ? "lock.fill" : season.icon).font(.system(size: 14))
                Text("SEZON \(season.number)").kerning(3)
            }
            .font(.custom("AvenirNext-Medium", size: 13))
            .foregroundStyle(.white.opacity(0.9))
            Text(season.name)
                .font(.custom("AvenirNext-UltraLight", size: 34))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.14), radius: 4, y: 1)
            Text(season.tagline)
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 8) {
                GemView(top: season.gemTopColor, bottom: season.gemBottomColor, size: 26, locked: !done)
                Text(done ? "Ödül alındı: \(season.rewardName)" : "Ödül: \(season.rewardName)")
                    .font(.custom("AvenirNext-Regular", size: 13))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 18).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 26).fill(.white.opacity(locked ? 0.10 : 0.20)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.45), lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(locked ? 0.7 : 1)
    }
}
