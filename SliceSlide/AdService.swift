import SwiftUI

/// Ödüllü reklam köprüsü.
///
/// Şu an gerçek reklam SDK'sı YOKTUR. Test derlemesinde (DEBUG) 5 saniyelik sahte bir "TEST REKLAMI" gösterilir.
/// Release derlemesinde `isAvailable` false olduğu için reklam düğmeleri hiç görünmez.
///
/// Gerçek reklam bağlamak için (ör. Google AdMob):
///  1. Swift Package olarak Google Mobile Ads SDK'yı ekle, Info.plist'e GADApplicationIdentifier yaz.
///  2. `showRewarded` içinde GADRewardedAd yükleyip göster; ödül kazanılınca `finish(true)`, kapatılırsa `finish(false)`.
///  3. `isAvailable` değerini reklamın yüklenip yüklenmediğine bağla.
///  4. Gerekli izinleri (ATT / GDPR-UMP onayı) ekle.
final class AdService: ObservableObject {
    static let shared = AdService()

    @Published var presenting = false
    private var completion: ((Bool) -> Void)?

    var isAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false   // gerçek reklam SDK'sı bağlanana kadar kapalı
        #endif
    }

    func showRewarded(_ completion: @escaping (Bool) -> Void) {
        guard isAvailable, !presenting else { completion(false); return }
        self.completion = completion
        presenting = true
    }

    func finish(_ rewarded: Bool) {
        presenting = false
        let c = completion
        completion = nil
        c?(rewarded)
    }
}

#if DEBUG
/// Sahte reklam: yalnızca test derlemesinde gösterilir.
struct MockAdView: View {
    @ObservedObject private var ads = AdService.shared
    @State private var remaining = 5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.04)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button {
                        ads.finish(remaining == 0)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(remaining == 0 ? 1 : 0.5))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.18)))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 10)
                Spacer()
                Text("TEST REKLAMI")
                    .font(.custom("AvenirNext-Medium", size: 14)).kerning(4)
                    .foregroundStyle(.white.opacity(0.7))
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Gerçek reklam bağlanınca burada gösterilecek.")
                    .font(.custom("AvenirNext-Regular", size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 5)
                    Circle().trim(from: 0, to: CGFloat(5 - remaining) / 5)
                        .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(remaining == 0 ? "✓" : "\(remaining)")
                        .font(.custom("AvenirNext-Medium", size: 26)).foregroundStyle(.white)
                }
                .frame(width: 70, height: 70)
                .animation(.linear(duration: 1), value: remaining)
                Spacer()
                if remaining == 0 {
                    PillButton(title: "Ödülü Al", width: 220, tint: .black) { ads.finish(true) }
                        .padding(.bottom, 50)
                } else {
                    Color.clear.frame(height: 118)
                }
            }
        }
        .onAppear { remaining = 5 }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if remaining > 0 { remaining -= 1 }
        }
    }
}
#endif
