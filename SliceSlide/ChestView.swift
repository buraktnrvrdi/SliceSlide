import SwiftUI

/// Günlük ödül: nadirlik seviyeli kristal sandık. Kristal kesilir, ödüller sırayla ortaya çıkar.
/// Reklam izleyerek %50 ihtimalle bir üst nadirliğe çıkarılabilir.
struct ChestView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var progress = PlayerProgress.shared
    @ObservedObject private var ads = AdService.shared

    private enum Stage { case closed, shaking, cutting, opened }

    @State private var tier = 0
    @State private var stage: Stage = .closed
    @State private var shake = false
    @State private var float = false
    @State private var sweep: CGFloat = 0
    @State private var sep: CGFloat = 0
    @State private var burst = false
    @State private var rewardIn = false
    @State private var result: ChestResult?
    @State private var shown = 0
    @State private var note: String?
    @State private var adBusy = false
    @State private var flash = false

    private var palette: Palette { Palette.forLevel(progress.unlocked) }
    private var season: Season { Season.of(level: progress.unlocked) }
    private var colors: [Color] { ChestTier.colors(tier, season: season) }
    private var accent: Color { tier == 2 ? Color(red: 1, green: 0.88, blue: 0.5) : (tier == 1 ? Color(red: 0.8, green: 0.84, blue: 1) : .white) }

    private struct Shard: Identifiable {
        let id: Int, angle: Double, dist: CGFloat, size: CGFloat, delay: Double, diamond: Bool, tint: Int
    }

    private let shards: [Shard] = (0..<56).map { i in
        Shard(id: i, angle: Double.random(in: 0..<(2 * .pi)), dist: CGFloat.random(in: 110...250),
              size: CGFloat.random(in: 5...13), delay: Double.random(in: 0...0.2), diamond: i % 3 != 0, tint: i % 3)
    }

    var body: some View {
        ZStack {
            PaletteBackground(palette: palette)
            Color.black.opacity(tier == 2 ? 0.26 : 0.12).ignoresSafeArea().animation(.easeInOut(duration: 0.5), value: tier)

            VStack(spacing: 0) {
                HStack {
                    CircleIconButton(systemName: "xmark", size: 44) {
                        withAnimation(.easeInOut(duration: 0.3)) { model.showChest = false }
                    }
                    .opacity((stage == .closed || stage == .opened) && !adBusy ? 1 : 0)
                    Spacer()
                }
                .padding(.horizontal, 22).padding(.top, 8)

                header.padding(.top, 6)

                Spacer(minLength: 0)

                stageArt
                    .scaleEffect(stage == .opened ? 0.66 : 1)
                    .frame(height: stage == .opened ? 230 : 350)
                    .contentShape(Rectangle())
                    .onTapGesture { if stage == .closed && !adBusy { open() } }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: stage)

                Spacer(minLength: 0)

                bottom
                    .padding(.bottom, 38)
            }

            Color.white.opacity(flash ? 0.65 : 0).ignoresSafeArea().allowsHitTesting(false)
                .animation(.easeOut(duration: 0.5), value: flash)
        }
        .onAppear {
            if !progress.chestReady { model.showChest = false; return }
            tier = progress.todaysChestTier()
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { float = true }
        }
    }

    // MARK: Başlık

    private var header: some View {
        VStack(spacing: 8) {
            Text(result?.jackpot == true ? "ÇİFTE SANDIK!" : "GÜNLÜK ÖDÜL")
                .font(.custom("AvenirNext-Medium", size: 14)).kerning(4)
                .foregroundStyle(result?.jackpot == true ? Color(red: 1, green: 0.9, blue: 0.5) : .white.opacity(0.92))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            Text("\(ChestTier.names[tier]) Sandık")
                .font(.custom("AvenirNext-UltraLight", size: 42))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.14), radius: 4, y: 1)
                .shadow(color: accent.opacity(0.7), radius: 12)
                .id(tier)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(i <= tier ? 1 : 0.28))
                        .shadow(color: .white.opacity(i <= tier ? 0.9 : 0), radius: 4)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: tier)
    }

    // MARK: Görsel

    private var stageArt: some View {
        let w: CGFloat = 190, h: CGFloat = 210
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [accent.opacity(stage == .opened ? 0.75 : 0.42), .clear], center: .center, startRadius: 0, endRadius: 190))
                .frame(width: 380, height: 380)
                .scaleEffect(float ? 1.08 : 0.94)

            if tier == 2 {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<9, id: \.self) { i in
                            Capsule()
                                .fill(LinearGradient(colors: [.clear, Color(red: 1, green: 0.93, blue: 0.6).opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                                .frame(width: 14, height: 420)
                                .rotationEffect(.degrees(Double(i) * 20 + t * 16))
                        }
                    }
                    .opacity(0.8)
                }
                .transition(.opacity)
            }

            ZStack {
                crystal(w: w, h: h)
                    .mask(alignment: .top) { Rectangle().frame(width: w + 60, height: h / 2) }
                    .shadow(color: accent.opacity(0.6), radius: 22)
                    .offset(x: -sep * 20, y: -sep * 34)
                    .rotationEffect(.degrees(Double(-sep) * 4))
                crystal(w: w, h: h)
                    .mask(alignment: .bottom) { Rectangle().frame(width: w + 60, height: h / 2) }
                    .shadow(color: accent.opacity(0.6), radius: 22)
                    .offset(x: sep * 20, y: sep * 40)
                    .rotationEffect(.degrees(Double(sep) * 4))

                Capsule()
                    .fill(LinearGradient(colors: [.clear, .white, .white, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 330 * sep, height: 10 + 70 * sep)
                    .blur(radius: 10 + 12 * sep)
                    .opacity(sep)

                Capsule()
                    .fill(.white)
                    .frame(width: (w + 130) * sweep, height: 4)
                    .shadow(color: .white, radius: 10)
                    .opacity(stage == .cutting ? 1 : 0)
                    .offset(x: -(w + 130) * (1 - sweep) / 2)
            }
            .id(tier)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .rotationEffect(.degrees(stage == .shaking ? (shake ? 2.6 : -2.6) : 0))
            .scaleEffect(stage == .shaking ? 1.07 : 1)
            .offset(y: stage == .closed ? (float ? -8 : 8) : 0)

            if tier >= 1 && stage != .opened {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<(tier == 2 ? 9 : 5), id: \.self) { i in
                            let a = t * 0.9 + Double(i) * (2 * .pi / Double(tier == 2 ? 9 : 5))
                            Circle()
                                .fill(.white)
                                .frame(width: 5, height: 5)
                                .shadow(color: accent, radius: 5)
                                .offset(x: CGFloat(cos(a)) * 150, y: CGFloat(sin(a)) * 120)
                        }
                    }
                }
            }

            ForEach(shards) { s in
                shardView(s)
                    .offset(x: burst ? CGFloat(cos(s.angle)) * s.dist * (tier == 2 ? 1.3 : 1) : 0,
                            y: burst ? CGFloat(sin(s.angle)) * s.dist * (tier == 2 ? 1.3 : 1) : 0)
                    .scaleEffect(burst ? 0.3 : 1)
                    .opacity(stage == .opened ? (burst ? 0 : 1) : 0)
                    .animation(.easeOut(duration: 1.25).delay(s.delay), value: burst)
            }

            if stage == .opened, let r = result {
                rewardBadge(r)
                    .scaleEffect(rewardIn ? 1 : 0.15)
                    .opacity(rewardIn ? 1 : 0)
                    .offset(y: rewardIn ? -6 : 24)
            }
        }
    }

    private func crystal(w: CGFloat, h: CGFloat) -> some View {
        let pts = ShapeKind.hexagon.points().map { CGPoint(x: w / 2 + $0.x * w / 2, y: h / 2 - $0.y * h / 2) }
        let path = Path(Geo.roundedPath(pts, radius: 24))
        return ZStack {
            path.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            path.fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)))
            Path { p in
                let c = CGPoint(x: w / 2, y: h / 2)
                for i in 0..<6 { p.move(to: c); p.addLine(to: pts[i]) }
            }
            .stroke(.white.opacity(0.14), lineWidth: 1)
            path.stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
        }
        .frame(width: w, height: h)
    }

    private func shardView(_ s: Shard) -> some View {
        let palette: [Color] = [.white, colors.first ?? .white, Color(red: 1, green: 0.9, blue: 0.6)]
        return Group {
            if s.diamond {
                RoundedRectangle(cornerRadius: 2).fill(palette[s.tint])
                    .frame(width: s.size, height: s.size * 1.6)
                    .rotationEffect(.degrees(s.angle * 57))
            } else {
                Circle().fill(palette[s.tint]).frame(width: s.size * 0.7, height: s.size * 0.7)
            }
        }
        .shadow(color: .white.opacity(0.9), radius: 6)
    }

    private func rewardBadge(_ r: ChestResult) -> some View {
        let icon = r.items.first.map { describe($0).icon } ?? "sparkles"
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.72)], startPoint: .top, endPoint: .bottom))
                .frame(width: 128, height: 128)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: accent.opacity(0.95), radius: 26)
            Circle().stroke(.white.opacity(0.55), lineWidth: 1.5).frame(width: 150, height: 150)
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: Alt bölüm

    @ViewBuilder private var bottom: some View {
        VStack(spacing: 12) {
            switch stage {
            case .closed:
                Text(note ?? "Kristali kesmek için dokun")
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    .padding(.horizontal, 30)
                    .frame(minHeight: 44)
                if AdService.shared.isAvailable && progress.chestBoostAvailable {
                    boostButton
                }
                PillButton(title: "Aç", width: 200, tint: season.gemBottomColor) { if !adBusy { open() } }
            case .shaking, .cutting:
                Text("…")
                    .font(.custom("AvenirNext-UltraLight", size: 40))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(height: 150)
            case .opened:
                if let r = result {
                    VStack(spacing: 8) {
                        ForEach(Array(r.items.enumerated()), id: \.element.id) { idx, item in
                            if idx < shown {
                                itemRow(item)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: shown)
                    PillButton(title: "Harika", width: 200, tint: season.gemBottomColor) {
                        withAnimation(.easeInOut(duration: 0.3)) { model.showChest = false }
                    }
                    .padding(.top, 6)
                    .opacity(shown >= r.items.count ? 1 : 0.35)
                    .allowsHitTesting(shown >= r.items.count)
                }
            }
        }
    }

    private var boostButton: some View {
        Button {
            watchAd()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reklam izle · %50 şans").font(.custom("AvenirNext-Medium", size: 15))
                    Text("\(ChestTier.names[min(tier + 1, 2)]) sandığa yüksel").font(.custom("AvenirNext-Regular", size: 12)).opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Capsule().fill(.white.opacity(0.22)))
            .overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 1.3))
            .shadow(color: .white.opacity(0.3), radius: 10)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(adBusy)
    }

    // MARK: Ödül satırları

    private func describe(_ item: ChestItem) -> (icon: String, title: String, sub: String?) {
        switch item.kind {
        case .hints(let n): return ("lightbulb.fill", "+\(n) İpucu", "Toplam \(progress.hints)")
        case .shield(let n): return ("shield.lefthalf.filled", "+\(n) Seri Kalkanı", "Toplam \(progress.shields)")
        case .fragments(let n):
            let p = progress.fragmentProgress
            let next = progress.nextFragmentSkin.map { " · Sonraki: \($0.name)" } ?? ""
            return ("diamond.fill", "+\(n) Kristal parçası", "\(p.have)/\(p.need)\(next)")
        case .trail(let id): return ("wand.and.stars", "Yeni kesim izi", Trail.all.first { $0.id == id }?.name)
        case .theme(let id): return ("paintpalette.fill", "Yeni tema", Season.all[id].name)
        case .skin(let id): return ("sparkles", "Yeni kristal açıldı!", Skin.all[id].name)
        }
    }

    private func itemRow(_ item: ChestItem) -> some View {
        let d = describe(item)
        return HStack(spacing: 12) {
            Image(systemName: d.icon)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.3)))
            VStack(alignment: .leading, spacing: 1) {
                Text(d.title).font(.custom("AvenirNext-Medium", size: 16))
                if let s = d.sub { Text(s).font(.custom("AvenirNext-Regular", size: 12)).opacity(0.9) }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.55), lineWidth: 1))
    }

    // MARK: Akış

    private func watchAd() {
        adBusy = true
        note = nil
        AdService.shared.showRewarded { ok in
            adBusy = false
            guard ok else { note = "Reklam tamamlanmadı. Sandık aynı kaldı."; return }
            let success = progress.boostChest()
            if success {
                flash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { flash = false }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { tier = progress.todaysChestTier() }
                SFX.shared.play(.perfect)
                Haptics.perfect()
                note = "Yükseldi! \(ChestTier.names[tier]) sandık kazandın."
            } else {
                Haptics.warning()
                SFX.shared.play(.deny)
                note = "Bu sefer olmadı. Sandığın aynı kaldı."
            }
        }
    }

    private func open() {
        guard stage == .closed else { return }
        SFX.shared.play(.tap)
        note = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { stage = .shaking }
        withAnimation(.easeInOut(duration: 0.06).repeatCount(16, autoreverses: true)) { shake = true }
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09 * Double(i)) { Haptics.tick() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            shake = false
            stage = .cutting
            withAnimation(.easeInOut(duration: 0.4)) { sweep = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            let r = progress.openChest()
            result = r
            SFX.shared.play(.cut)
            Haptics.cut()
            stage = .opened
            withAnimation(.spring(response: 0.7, dampingFraction: 0.62)) { sep = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { burst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                SFX.shared.play(.perfect)
                Haptics.perfect()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { rewardIn = true }
                if r?.jackpot == true || tier == 2 { flash = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { flash = false } }
            }
            // Ödüller sırayla belirir
            let count = r?.items.count ?? 0
            for i in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75 + 0.38 * Double(i)) {
                    shown = i + 1
                    SFX.shared.playNote(i * 2 + 1)
                    Haptics.land()
                }
            }
        }
    }
}
