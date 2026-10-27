import SwiftUI

struct PaletteBackground: View {
    let palette: Palette
    var intensity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.topColor, palette.bottomColor], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.white.opacity(0.30 + 0.06 * intensity), .clear], center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 0, endRadius: 380 + 30 * intensity)
            if ThemeSet.active?.decor == .candy { CandyClouds() }
        }
        .ignoresSafeArea()
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Yumuşak, parıltılı oval buton.
struct PillButton: View {
    let title: String
    var width: CGFloat = 220
    var tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            SFX.shared.play(.tap)
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.custom("AvenirNext-Regular", size: 26))
                .kerning(2)
                .foregroundStyle(tint)
                .frame(width: width, height: 68)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.72)],
                                             startPoint: .top, endPoint: .bottom))
                )
                .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1.5))
                .shadow(color: .white.opacity(0.6), radius: 18)
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 52
    var filled = false
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button {
            SFX.shared.play(.tap)
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .regular))
                .foregroundStyle(filled ? tint : .white)
                .frame(width: size, height: size)
                .background(Circle().fill(filled ? Color.white.opacity(0.92) : Color.white.opacity(0.22)))
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                .shadow(color: .white.opacity(filled ? 0.5 : 0.2), radius: 12)
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct StarsRow: View {
    let count: Int
    var size: CGFloat = 40

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .light))
                    .foregroundStyle(.white.opacity(i < count ? 1 : 0.4))
                    .shadow(color: .white.opacity(i < count ? 0.8 : 0), radius: 10)
            }
        }
    }
}

/// Sezon ödülü / skin kristali.
struct GemView: View {
    let colors: [Color]
    var size: CGFloat = 90
    var locked = false

    init(top: Color, bottom: Color, size: CGFloat = 90, locked: Bool = false) {
        colors = [top, bottom]; self.size = size; self.locked = locked
    }
    init(colors: [Color], size: CGFloat = 90, locked: Bool = false) {
        self.colors = colors; self.size = size; self.locked = locked
    }

    var body: some View {
        let pts = ShapeKind.hexagon.points().map {
            CGPoint(x: size / 2 + $0.x * size / 2 * 0.92, y: size / 2 - $0.y * size / 2 * 0.92)
        }
        let path = Path(Geo.roundedPath(pts, radius: size * 0.12))
        ZStack {
            path.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            path.fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center))
            path.stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.5), radius: size * 0.12)
        .saturation(locked ? 0 : 1)
        .opacity(locked ? 0.45 : 1)
    }
}

/// Müzik ve ses efekti aç/kapa düğmeleri.
struct AudioToggles: View {
    var compact = false
    @AppStorage("musicOn") private var musicOn = true
    @AppStorage("sfxOn") private var sfxOn = true

    var body: some View {
        HStack(spacing: 12) {
            labeled("Müzik") {
                CircleIconButton(systemName: musicOn ? "music.note" : "music.note.slash", size: compact ? 44 : 54) {
                    musicOn.toggle()
                    Music.shared.refresh()
                }
            }
            labeled("Efekt") {
                CircleIconButton(systemName: sfxOn ? "speaker.wave.2.fill" : "speaker.slash.fill", size: compact ? 44 : 54) {
                    sfxOn.toggle()
                }
            }
        }
    }

    private func labeled<V: View>(_ title: String, @ViewBuilder _ button: () -> V) -> some View {
        VStack(spacing: 3) {
            button()
            Text(title)
                .font(.custom("AvenirNext-Medium", size: 10))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
    }
}
