import SwiftUI

/// İlk açılışta (ve ana menüdeki "?" ile) gösterilen başlangıç rehberi.
struct IntroView: View {
    let palette: Palette
    let onDone: () -> Void
    @State private var page = 0

    private struct Page {
        let title: String
        let text: String
        let art: Art
    }
    enum Art { case swipe, targets, training, ramp }

    private let pages: [Page] = [
        Page(title: L("Kes"), text: L("Ekranın herhangi bir yerinden parmağını düz bir çizgide sürükle. Şekil çizgi boyunca ikiye ayrılır."), art: .swipe),
        Page(title: L("Hedefi tuttur"), text: L("Alttaki halkalar parçaların ne kadar büyük olması gerektiğini söyler. Örneğin %%%lld ve %%%lld yazıyorsa şekli o oranda böl; her parça kendisine uyan halkaya kendiliğinden düşer.", 30, 70), art: .targets),
        Page(title: L("İlk 5 bölüm eğitim"), text: L("Eğitim bölümlerinde sürüklerken parçaların yüzdesini canlı görürsün. 6. bölümden itibaren bu yardım kalkar; yüzdeleri kesimden sonra görürsün ve kesimi gözle ayarlarsın."), art: .training),
        Page(title: L("Zorluk yavaş artar"), text: L("Önce tek kesim ve basit şekiller. Sonra dengesiz oranlar, kesilemeyen koyu çekirdekler, birden fazla kesim ve en sonda zaman sınırı gelir. Hedefe yeterince yaklaşırsan bölüm geçilir."), art: .ramp),
    ]

    var body: some View {
        ZStack {
            PaletteBackground(palette: palette)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(L("Geç")) { finish() }
                        .font(.custom("AvenirNext-Regular", size: 17))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 24).padding(.top, 12)
                        .opacity(page < pages.count - 1 ? 1 : 0)
                }

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 28) {
                            IntroArt(art: pages[i].art, palette: palette)
                                .frame(height: 260)
                            Text(pages[i].title)
                                .font(.custom("AvenirNext-UltraLight", size: 34))
                                .kerning(2)
                                .foregroundStyle(.white)
                                .shadow(color: .white.opacity(0.5), radius: 10)
                            Text(pages[i].text)
                                .font(.custom("AvenirNext-Regular", size: 18))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 34)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 24)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 10) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule().fill(.white.opacity(i == page ? 1 : 0.35))
                            .frame(width: i == page ? 30 : 9, height: 9)
                    }
                }
                .padding(.bottom, 22)

                PillButton(title: page == pages.count - 1 ? L("Başla") : L("Devam"), width: 220,
                           tint: palette.shapeBottomColor) {
                    if page == pages.count - 1 { finish() }
                    else { withAnimation(.easeInOut(duration: 0.3)) { page += 1 } }
                }
                .padding(.bottom, 44)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "seenIntro")
        onDone()
    }
}

private struct IntroArt: View {
    let art: IntroView.Art
    let palette: Palette

    private var fill: LinearGradient {
        LinearGradient(colors: [palette.shapeTopColor, palette.shapeBottomColor], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2)
            let sweep = min(1, max(0, (t - 0.4) / 0.7))
            let sep = min(1, max(0, (t - 1.1) / 0.6))
            switch art {
            case .swipe:
                ZStack {
                    split(top: 0.5, sep: sep)
                    Capsule().fill(.white).frame(width: 240 * sweep, height: 4)
                        .shadow(color: .white, radius: 8)
                        .offset(x: -120 * (1 - sweep), y: 0)
                        .opacity(sep > 0.8 ? 0 : 1)
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 34)).foregroundStyle(.white)
                        .offset(x: -120 + 240 * sweep, y: 26)
                        .opacity(t < 1.2 ? 1 : 0)
                }
            case .targets:
                VStack(spacing: 22) {
                    split(top: 0.3, sep: 1).scaleEffect(0.62).frame(height: 140)
                    HStack(spacing: 60) {
                        ring(pctText(30), 38)
                        ring(pctText(70), 56)
                    }
                }
            case .training:
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(fill).frame(width: 150, height: 170)
                    Rectangle().fill(.white).frame(width: 230, height: 4).shadow(color: .white, radius: 6).offset(y: 12)
                    Text(pctText(58)).font(.custom("AvenirNext-Medium", size: 26)).foregroundStyle(.white).offset(y: -30)
                    Text(pctText(42)).font(.custom("AvenirNext-Medium", size: 26)).foregroundStyle(.white).offset(y: 52)
                }
            case .ramp:
                HStack(alignment: .bottom, spacing: 16) {
                    ForEach(0..<5, id: \.self) { i in
                        VStack(spacing: 8) {
                            Image(systemName: ["scissors", "percent", "circle.fill", "square.on.square", "timer"][i])
                                .font(.system(size: 22)).foregroundStyle(.white)
                            Capsule().fill(.white.opacity(0.4 + 0.12 * Double(i)))
                                .frame(width: 34, height: 50 + CGFloat(i) * 34)
                        }
                    }
                }
            }
        }
    }

    private func ring(_ text: String, _ r: CGFloat) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.white.opacity(0.7), lineWidth: 3).frame(width: r * 2, height: r * 2)
                Circle().fill(.white.opacity(0.12)).frame(width: r * 1.45, height: r * 1.45)
            }
            .shadow(color: .white.opacity(0.5), radius: 8)
            Text(text).font(.custom("AvenirNext-Medium", size: 20)).foregroundStyle(.white)
        }
    }

    private func split(top: CGFloat, sep: Double) -> some View {
        let h: CGFloat = 170, w: CGFloat = 170
        let topH = h * top
        return ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 16)
                .fill(fill).frame(width: w, height: topH)
                .offset(x: -CGFloat(sep) * 10, y: -h / 2 + topH / 2 - CGFloat(sep) * 8)
            UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 2)
                .fill(fill).frame(width: w, height: h - topH)
                .offset(x: CGFloat(sep) * 10, y: topH / 2 + CGFloat(sep) * 10)
        }
        .frame(width: w + 40, height: h + 40)
        .shadow(color: .white.opacity(0.4), radius: 14)
    }
}
