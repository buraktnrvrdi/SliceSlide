import SwiftUI

/// Kişiselleştirme: tema setleri, kristal skinleri, kesim izleri ve arka plan temaları.
struct CollectionView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var progress = PlayerProgress.shared

    private enum Tab: Int, CaseIterable {
        case set, crystal, trail, theme
        var title: String { L(["Set", "Kristal", "İz", "Tema"][rawValue]) }
        var icon: String { ["square.stack.3d.up.fill", "diamond.fill", "wand.and.stars", "paintpalette.fill"][rawValue] }
    }

    @State private var tab: Tab = .set
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack(alignment: .top) {
            PaletteBackground(palette: Palette.forLevel(progress.unlocked))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    tabs
                    if tab == .crystal { fragmentCard }
                    if tab == .set { setInfoCard }
                    LazyVGrid(columns: columns, spacing: 14) {
                        switch tab {
                        case .set: setCards
                        case .crystal: crystalCards
                        case .trail: trailCards
                        case .theme: themeCards
                        }
                    }
                    .id(tab)   // sekmeler aynı kimlikleri (0, 1…) kullanıyor: kartlar karışmasın
                }
                .padding(.horizontal, 20)
                .padding(.top, 100)
                .padding(.bottom, 40)
            }

            HStack {
                CircleIconButton(systemName: "chevron.left", size: 46) { model.go(.map) }
                Spacer()
                Text(L("Kişiselleştir"))
                    .font(.custom("AvenirNext-Medium", size: 28))
                    .kerning(2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                Spacer()
                Color.clear.frame(width: 46, height: 46)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: Sekmeler

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.rawValue) { t in
                Button {
                    SFX.shared.play(.tap)
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon).font(.system(size: 13))
                        Text(t.title).font(.custom("AvenirNext-Medium", size: 14))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(.white.opacity(tab == t ? 0.36 : 0.14)))
                    .overlay(Capsule().stroke(.white.opacity(tab == t ? 0.95 : 0.4), lineWidth: tab == t ? 1.6 : 1))
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    private var fragmentCard: some View {
        let p = progress.fragmentProgress
        let next = progress.nextFragmentSkin
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "diamond.fill")
                Text(L("Kristal parçaları")).font(.custom("AvenirNext-Medium", size: 15))
                Spacer()
                Text(next != nil ? "\(p.have)/\(p.need)" : L("Tamam (durum)")).font(.custom("AvenirNext-Medium", size: 15)).monospacedDigit()
            }
            .foregroundStyle(.white)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25)).frame(height: 8)
                Capsule().fill(.white).frame(width: max(8, (UIScreen.main.bounds.width - 76) * CGFloat(next != nil ? p.have : p.need) / CGFloat(p.need)), height: 8)
                    .shadow(color: .white.opacity(0.8), radius: 5)
            }
            Text(next.map { L("Sonraki kristal: %@ · Günlük sandıktan parça topla", $0.name) } ?? L("Tüm parça kristalleri açıldı!"))
                .font(.custom("AvenirNext-Regular", size: 12))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.2)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.5), lineWidth: 1))
    }

    private var setInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 22))
            Text(L("Tema seti arka planı, kristalleri, kesim izini, sesleri ve müziği birlikte değiştirir. Kristal ve İz sekmelerinden ayrıca seçim yaparsan o seçim öne geçer."))
                .font(.custom("AvenirNext-Regular", size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.2)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.5), lineWidth: 1))
    }

    // MARK: Kartlar

    @ViewBuilder private var setCards: some View {
        pick(selected: progress.selectedSet < 0, locked: false, title: L("Set Yok"), sub: L("Sezonun kendi havası"),
             art: { Image(systemName: "circle.dashed").font(.system(size: 38)).foregroundStyle(.white).frame(height: 86) }) {
            chooseSet(-1)
        }
        ForEach(ThemeSet.all) { set in
            let open = progress.setUnlocked(set.id)
            let pal = Palette.all[set.paletteIDs[0]]
            pick(selected: progress.selectedSet == set.id && open, locked: !open, title: set.name,
                 sub: open ? set.tagline : L("Sezon %lld'i bitir", set.unlockSeason + 1),
                 art: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [pal.topColor, pal.bottomColor], startPoint: .top, endPoint: .bottom))
                        .frame(width: 96, height: 86)
                        .overlay(Circle().fill(.white.opacity(0.45)).frame(width: 46).blur(radius: 8).offset(x: -24, y: -22))
                        .overlay(Circle().fill(.white.opacity(0.35)).frame(width: 38).blur(radius: 7).offset(x: 26, y: 24))
                        .overlay(GemView(colors: set.swiftShapeColors, size: 40))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "heart.fill").font(.system(size: 12)).foregroundStyle(.white).padding(7)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.85), lineWidth: 1.5))
                        .saturation(open ? 1 : 0)
                        .opacity(open ? 1 : 0.55)
                 }) {
                chooseSet(set.id)
            }
        }
    }

    private func chooseSet(_ id: Int) {
        progress.selectSet(id)
        // Müzik yeni sete (ya da sezona) geçsin
        Music.shared.play(season: Season.of(level: progress.unlocked).index)
    }

    @ViewBuilder private var crystalCards: some View {
        pick(selected: progress.selectedSkin < 0, locked: false, title: L("Sezon Rengi"), sub: L("Sezonun kendi renkleri"),
             art: { Image(systemName: "paintpalette.fill").font(.system(size: 38)).foregroundStyle(.white).frame(height: 86) }) {
            progress.selectSkin(-1)
        }
        ForEach(Skin.all) { skin in
            let open = progress.skinUnlocked(skin.id)
            pick(selected: progress.selectedSkin == skin.id && open, locked: !open, title: skin.name, sub: skinSub(skin, open),
                 art: { GemView(colors: skin.swiftColors, size: 86, locked: !open) }) {
                progress.selectSkin(skin.id)
            }
        }
    }

    private func skinSub(_ skin: Skin, _ open: Bool) -> String {
        switch skin.source {
        case .season(let s): return open ? L("Sezon %lld ödülü", s + 1) : L("Sezon %lld'i bitir", s + 1)
        case .fragments(let k): return open ? L("Parça ödülü") : L("%lld parça topla", k * Skin.fragmentsPerSkin)
        }
    }

    @ViewBuilder private var trailCards: some View {
        ForEach(Trail.all) { t in
            let open = progress.trailUnlocked(t.id)
            pick(selected: progress.selectedTrail == t.id && open, locked: !open, title: t.name,
                 sub: t.id == 0 ? L("Sezonun kendi efekti") : (open ? L("Açıldı") : L("Günlük sandıktan çıkar")),
                 art: { trailArt(t, open) }) {
                progress.selectTrail(t.id)
            }
        }
    }

    private func trailArt(_ t: Trail, _ open: Bool) -> some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [.clear, Color(t.line), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 100, height: 4)
                .shadow(color: Color(t.line), radius: 6)
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(Color(t.colors[i % t.colors.count]))
                    .frame(width: CGFloat(4 + (i % 3) * 2), height: CGFloat(4 + (i % 3) * 2))
                    .offset(x: CGFloat(i - 3) * 14 + 7, y: CGFloat(i % 2 == 0 ? -16 : 16))
            }
            Image(systemName: t.icon).font(.system(size: 20)).foregroundStyle(.white).offset(y: 0)
        }
        .frame(height: 86)
        .saturation(open ? 1 : 0)
        .opacity(open ? 1 : 0.5)
    }

    @ViewBuilder private var themeCards: some View {
        pick(selected: progress.selectedTheme < 0, locked: false, title: L("Sezon Teması"), sub: L("Sezona göre değişir"),
             art: { Image(systemName: "sun.and.horizon.fill").font(.system(size: 38)).foregroundStyle(.white).frame(height: 86) }) {
            progress.selectTheme(-1)
        }
        ForEach(Season.all) { s in
            let open = progress.themeUnlocked(s.index)
            let pal = Palette.all[s.paletteIDs[0]]
            pick(selected: progress.selectedTheme == s.index && open, locked: !open, title: s.name,
                 sub: open ? L("Açıldı") : L("Sezonu bitir ya da sandıktan çıkar"),
                 art: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [pal.topColor, pal.bottomColor], startPoint: .top, endPoint: .bottom))
                        .frame(width: 70, height: 86)
                        .overlay(GemView(top: pal.shapeTopColor, bottom: pal.shapeBottomColor, size: 36))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.8), lineWidth: 1.5))
                        .saturation(open ? 1 : 0)
                        .opacity(open ? 1 : 0.55)
                 }) {
                progress.selectTheme(s.index)
            }
        }
    }

    private func pick<Art: View>(selected: Bool, locked: Bool, title: String, sub: String,
                                 @ViewBuilder art: () -> Art, action: @escaping () -> Void) -> some View {
        Button {
            if locked {
                SFX.shared.play(.deny)
                Haptics.warning()
            } else {
                SFX.shared.play(.tap)
                Haptics.tap()
                action()
            }
        } label: {
            VStack(spacing: 8) {
                art()
                Text(title).font(.custom("AvenirNext-Medium", size: 16)).foregroundStyle(.white).lineLimit(1)
                Text(sub).font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center).lineLimit(2).frame(height: 28)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(.vertical, 12).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 24).fill(.white.opacity(selected ? 0.36 : 0.18)))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(selected ? 1 : 0.5), lineWidth: selected ? 2.5 : 1.2))
            .overlay(alignment: .topTrailing) {
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 21)).foregroundStyle(.white).padding(10) }
                else if locked { Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).padding(12) }
            }
            .shadow(color: .white.opacity(selected ? 0.5 : 0), radius: 12)
        }
        .buttonStyle(PressScaleStyle())
    }
}
