import SwiftUI
import UIKit

/// Tema seti: arka plan, kristaller, kesim izi, sesler, müzik ve kutlamayı tek pakette değiştirir.
struct ThemeSet: Identifiable {
    enum Decor { case candy }

    let id: Int
    let name: String
    let tagline: String
    let paletteIDs: [Int]
    let shapeColors: [UIColor]
    let fx: CutFX
    /// Sürükleme sırasında çizilen kesim çizgisinin rengi.
    let drawLine: UIColor
    let sfx: Int            // SFX kesim sesi bankası
    let music: Int          // MusicSynth parça numarası
    let decor: Decor
    let unlockSeason: Int   // bu sezon bitince açılır

    var swiftShapeColors: [Color] { shapeColors.map { Color($0) } }

    static let all: [ThemeSet] = [
        ThemeSet(id: 0, name: L("Pamuk Şeker"), tagline: L("Tatlı, yumuşak, pespembe"),
                 paletteIDs: [18, 19, 20],
                 shapeColors: [UIColor(255, 240, 248), UIColor(255, 176, 216), UIColor(238, 118, 186)],
                 fx: CutFX(colors: [UIColor(255, 120, 184), UIColor(255, 196, 228), UIColor(255, 255, 255), UIColor(206, 176, 255), UIColor(170, 236, 220)],
                           kind: 5, gravity: 30, line: UIColor(255, 150, 206)),
                 drawLine: UIColor(255, 112, 182),
                 sfx: 6, music: 6, decor: .candy, unlockSeason: 0),
    ]

    /// Şu an seçili ve açık olan set.
    static var active: ThemeSet? {
        let p = PlayerProgress.shared
        guard all.indices.contains(p.selectedSet), p.setUnlocked(p.selectedSet) else { return nil }
        return all[p.selectedSet]
    }
}

/// Pamuk Şeker arka planı: yavaşça süzülen pamuk bulutları.
struct CandyClouds: View {
    private struct Cloud { let y: CGFloat; let scale: CGFloat; let speed: CGFloat; let phase: CGFloat; let tint: Color }
    private let clouds: [Cloud] = [
        Cloud(y: 0.10, scale: 1.25, speed: 9, phase: 0.05, tint: .white),
        Cloud(y: 0.26, scale: 0.80, speed: 14, phase: 0.55, tint: Color(red: 1, green: 0.86, blue: 0.94)),
        Cloud(y: 0.44, scale: 1.05, speed: 7, phase: 0.30, tint: .white),
        Cloud(y: 0.63, scale: 0.70, speed: 12, phase: 0.80, tint: Color(red: 0.93, green: 0.86, blue: 1)),
        Cloud(y: 0.80, scale: 1.30, speed: 6, phase: 0.15, tint: Color(red: 1, green: 0.9, blue: 0.96)),
        Cloud(y: 0.95, scale: 0.95, speed: 10, phase: 0.65, tint: .white),
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate)
                ZStack {
                    ForEach(clouds.indices, id: \.self) { i in
                        let c = clouds[i]
                        let span = geo.size.width + 260
                        let x = (c.phase * span + t * c.speed).truncatingRemainder(dividingBy: span) - 130
                        puff(c.tint)
                            .scaleEffect(c.scale)
                            .position(x: x, y: geo.size.height * c.y + sin(t * 0.3 + CGFloat(i)) * 6)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func puff(_ tint: Color) -> some View {
        ZStack {
            Circle().frame(width: 90, height: 90).offset(x: -46, y: 10)
            Circle().frame(width: 120, height: 120).offset(x: 0, y: -8)
            Circle().frame(width: 84, height: 84).offset(x: 50, y: 12)
            Capsule().frame(width: 190, height: 60).offset(y: 30)
        }
        .foregroundStyle(tint)
        .blur(radius: 16)
        .opacity(0.26)
    }
}
