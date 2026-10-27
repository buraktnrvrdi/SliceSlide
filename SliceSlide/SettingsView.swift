import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var progress = PlayerProgress.shared
    @ObservedObject private var gc = GameCenter.shared
    @AppStorage("musicOn") private var musicOn = true
    @AppStorage("sfxOn") private var sfxOn = true
    @AppStorage("hapticsOn") private var hapticsOn = true
    @AppStorage("notifyOn") private var notifyOn = true
    @State private var testMsg: String?

    private var accent: Color { Color(red: 0.42, green: 0.82, blue: 0.68) }

    var body: some View {
        ZStack(alignment: .top) {
            PaletteBackground(palette: Palette.forLevel(progress.unlocked))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    section("SES VE TİTREŞİM") {
                        toggleRow("music.note", "Müzik", $musicOn) { Music.shared.refresh() }
                        divider
                        toggleRow("speaker.wave.2.fill", "Efekt sesleri", $sfxOn) {}
                        divider
                        toggleRow("iphone.radiowaves.left.and.right", "Titreşim", $hapticsOn) { if hapticsOn { Haptics.cut() } }
                    }

                    section("BİLDİRİMLER", footer: "Günde en fazla iki bildirim: öğlen sandık, akşam seri hatırlatması.") {
                        toggleRow("bell.fill", "Hatırlatmalar", $notifyOn) {
                            if notifyOn { Reminders.requestIfNeeded() } else { Reminders.cancelAll() }
                        }
                    }

                    section("OYUN") {
                        navRow("questionmark.circle.fill", "Rehberi tekrar göster") {
                            model.go(.home)
                            withAnimation(.easeInOut(duration: 0.35)) { model.showIntro = true }
                        }
                        divider
                        navRow("sparkles", "Kişiselleştir") { model.go(.collection) }
                        divider
                        valueRow("gamecontroller.fill", "Game Center", gc.isAuthenticated ? "Bağlı" : "Bağlı değil")
                    }

                    section("ENVANTER") {
                        valueRow("lightbulb.fill", "İpucu hakkı", "\(progress.hints)")
                        divider
                        valueRow("shield.lefthalf.filled", "Seri Kalkanı", "\(progress.shields)")
                        divider
                        valueRow("diamond.fill", "Kristal parçası", "\(progress.fragmentProgress.have)/\(progress.fragmentProgress.need)")
                    }

                    #if DEBUG
                    section("GELİŞTİRİCİ · yayında kaldırılacak", footer: testMsg) {
                        navRow("gift.fill", "Sandığı sıfırla") { progress.debugResetChest(); testMsg = "Günlük sandık yeniden açılabilir." }
                        divider
                        navRow("calendar.badge.clock", "Günlük meydanı sıfırla") { progress.debugResetDaily(); testMsg = "Günlük meydan okuma yeniden oynanabilir." }
                        divider
                        navRow("diamond.fill", "+6 kristal parçası") { progress.debugAddFragments(6); testMsg = "+6 kristal parçası eklendi." }
                        divider
                        navRow("lightbulb.fill", "+10 ipucu") { progress.debugAddHints(10); testMsg = "+10 ipucu eklendi." }
                    }
                    #endif

                    Text("Slice & Slide · Sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.custom("AvenirNext-Regular", size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 96)
                .padding(.bottom, 40)
            }

            HStack {
                CircleIconButton(systemName: "chevron.left", size: 44) { model.go(.home) }
                Spacer()
                Text("Ayarlar")
                    .font(.custom("AvenirNext-Medium", size: 26))
                    .kerning(2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 1)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: Yapı taşları

    private func section<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("AvenirNext-Medium", size: 11)).kerning(2.5)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.leading, 14)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.2)))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.45), lineWidth: 1))
            if let footer {
                Text(footer)
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.3)).frame(height: 0.7).padding(.leading, 58)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.26)))
    }

    private func toggleRow(_ i: String, _ title: String, _ value: Binding<Bool>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            icon(i)
            Text(title).font(.custom("AvenirNext-Medium", size: 16)).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: value)
                .labelsHidden()
                .tint(accent)
                .onChange(of: value.wrappedValue) { _, _ in onChange() }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func navRow(_ i: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button {
            SFX.shared.play(.tap)
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                icon(i)
                Text(title).font(.custom("AvenirNext-Medium", size: 16))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func valueRow(_ i: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            icon(i)
            Text(title).font(.custom("AvenirNext-Medium", size: 16))
            Spacer()
            Text(value).font(.custom("AvenirNext-Regular", size: 15)).monospacedDigit().opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
