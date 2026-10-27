import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var progress = PlayerProgress.shared

    var body: some View {
        ZStack(alignment: .top) {
            PaletteBackground(palette: Palette.forLevel(progress.unlocked))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    summary
                    ForEach(Achievement.all) { a in row(a) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 100)
                .padding(.bottom, 40)
            }

            HStack {
                CircleIconButton(systemName: "chevron.left", size: 46) { model.go(.home) }
                Spacer()
                Text("Başarımlar")
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

    private var summary: some View {
        HStack(spacing: 18) {
            stat("trophy.fill", "\(progress.achieved.count)/\(Achievement.all.count)", "başarım")
            stat("star.fill", "\(progress.totalStars)", "yıldız")
            stat("flame.fill", "\(progress.bestStreak)", "en iyi seri")
            stat("lightbulb.fill", "\(progress.hints)", "ipucu")
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white.opacity(0.2)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.5), lineWidth: 1))
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16))
            Text(value).font(.custom("AvenirNext-Medium", size: 18))
            Text(label).font(.custom("AvenirNext-Regular", size: 11)).opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    private func row(_ a: Achievement) -> some View {
        let done = progress.achieved.contains(a.id)
        let v = min(a.value(progress), a.goal)
        return HStack(spacing: 14) {
            Image(systemName: a.icon)
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(done ? Color.white.opacity(0.35) : Color.white.opacity(0.12)))
                .overlay(Circle().stroke(.white.opacity(done ? 0.9 : 0.35), lineWidth: 1.5))
                .shadow(color: .white.opacity(done ? 0.6 : 0), radius: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(a.title).font(.custom("AvenirNext-Medium", size: 17))
                Text(a.detail).font(.custom("AvenirNext-Regular", size: 13)).opacity(0.9)
                if !done {
                    ProgressView(value: Double(v), total: Double(a.goal))
                        .tint(.white)
                        .frame(height: 4)
                    Text("\(v) / \(a.goal)").font(.custom("AvenirNext-Regular", size: 11)).opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
            if done {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(done ? 0.26 : 0.14)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(done ? 0.8 : 0.35), lineWidth: 1))
        .opacity(done ? 1 : 0.9)
    }
}

/// Yeni başarım kazanılınca üstten kayan bildirim.
struct AchievementToast: View {
    @ObservedObject private var progress = PlayerProgress.shared
    @State private var current: Achievement?

    var body: some View {
        VStack {
            if let a = current {
                HStack(spacing: 12) {
                    Image(systemName: a.icon).font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Başarım kazanıldı").font(.custom("AvenirNext-Regular", size: 11)).opacity(0.85)
                        Text(a.title).font(.custom("AvenirNext-Medium", size: 16))
                    }
                    Spacer(minLength: 6)
                    HStack(spacing: 4) { Image(systemName: "lightbulb.fill"); Text("+1") }
                        .font(.custom("AvenirNext-Medium", size: 14))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 30)
                .padding(.top, 54)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .onChange(of: progress.toasts.count) { _, _ in advance() }
        .onAppear { advance() }
    }

    private func advance() {
        guard current == nil, let next = progress.toasts.first else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { current = next }
        SFX.shared.play(.win)
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeInOut(duration: 0.35)) { current = nil }
            if !progress.toasts.isEmpty { progress.toasts.removeFirst() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
        }
    }
}
