import AVFoundation
import UIKit

/// Taptic Engine geri bildirimleri.
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let note = UINotificationFeedbackGenerator()
    private static let select = UISelectionFeedbackGenerator()
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    static func prepare() { rigid.prepare(); soft.prepare(); note.prepare(); select.prepare(); heavy.prepare() }
    static func tick() { guard Prefs.hapticsOn else { return }; select.selectionChanged(); select.prepare() }
    static func land() { guard Prefs.hapticsOn else { return }; soft.impactOccurred(intensity: 0.85); soft.prepare() }
    static func perfect() {
        guard Prefs.hapticsOn else { return }
        heavy.impactOccurred(intensity: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { rigid.impactOccurred(intensity: 0.8) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { note.notificationOccurred(.success) }
    }
    static func cut(soft gentle: Bool = false) {
        guard Prefs.hapticsOn else { return }
        if gentle { soft.impactOccurred(intensity: 0.75); soft.prepare() } else { rigid.impactOccurred(intensity: 0.9); rigid.prepare() }
    }
    static func tap() { guard Prefs.hapticsOn else { return }; soft.impactOccurred(intensity: 0.7) }
    static func success() { guard Prefs.hapticsOn else { return }; note.notificationOccurred(.success) }
    static func error() { guard Prefs.hapticsOn else { return }; note.notificationOccurred(.error) }
    static func warning() { guard Prefs.hapticsOn else { return }; note.notificationOccurred(.warning) }
}

enum SFXKind: Hashable { case cut, win, fail, tap, deny, perfect }

/// Dosya gerektirmeyen, kodla üretilen cam/ahşap benzeri sesler.
final class SFX {
    static let shared = SFX()
    private let rate = 44100.0
    private var bank: [SFXKind: [Data]] = [:]
    private var cutBank: [[Data]] = []
    private var noteBank: [Data] = []
    var season = 0
    private var active: [AVAudioPlayer] = []

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        func noise() -> Double { Double.random(in: -1...1) }
        // 0: cam tıngırtısı
        let glass = [1760.0, 1980.0, 2349.0].map { pitch in
            wav(tone(0.34) { t in
                let env = exp(-t * 13)
                let tink = 0.5 * sin(2 * .pi * pitch * t) + 0.28 * sin(2 * .pi * pitch * 1.5 * t) + 0.14 * sin(2 * .pi * pitch * 2.76 * t)
                return (tink * env + noise() * exp(-t * 150) * 0.55) * 0.55
            })
        }
        // 1: buz çatırtısı + parlak çan
        let ice = [0.0, 0.03, 0.06].map { off in
            wav(tone(0.42) { t in
                let c1 = noise() * exp(-t * 70) * 0.5
                let c2 = t > 0.045 + off ? noise() * exp(-(t - 0.045 - off) * 90) * 0.35 : 0
                let chime = (0.45 * sin(2 * .pi * 2637 * t) + 0.3 * sin(2 * .pi * 3520 * t) + 0.2 * sin(2 * .pi * 4186 * t)) * exp(-t * 8) * 0.5
                return c1 + c2 + chime
            })
        }
        // 2: ahşap tok + kum hışırtısı
        let wood = [1.0, 1.12, 0.9].map { k in
            wav(tone(0.32) { t in
                let phase = 2 * .pi * (120 * k * t + 130 * k * (1 - exp(-6 * t)) / 6)
                return sin(phase) * exp(-t * 16) * 0.8 + noise() * exp(-t * 90) * 0.3 + noise() * exp(-t * 9) * 0.07
            })
        }
        // 3: marimba + yaprak hışırtısı
        let marimba = [784.0, 880.0, 988.0].map { f in
            wav(tone(0.4) { t in
                (sin(2 * .pi * f * t) * exp(-t * 9) + 0.4 * sin(2 * .pi * f * 4 * t) * exp(-t * 30)) * 0.6 + noise() * exp(-t * 25) * 0.18
            })
        }
        // 4: nova sentez zap
        let nova = [1.0, 1.15, 0.88].map { k in
            wav(tone(0.4) { t in
                let phase = 2 * .pi * k * (300 * t + 2100 * (1 - exp(-14 * t)) / 14)
                let shimmer = sin(2 * .pi * 1800 * k * t) * 0.2 * exp(-t * 5) * (0.5 + 0.5 * sin(2 * .pi * 30 * t))
                return sin(phase) * exp(-t * 7) * 0.5 + shimmer
            })
        }
        // 5: Akış modu — neon elektronik zap
        let flowCut = [1.0, 1.12, 1.26].map { k in
            wav(tone(0.34) { t in
                let phase = 2 * .pi * k * (500 * t + 3200 * (1 - exp(-22 * t)) / 22)
                let zap = sin(phase) * exp(-t * 9) * 0.5
                let click = noise() * exp(-t * 180) * 0.35
                let sparkle = (sin(2 * .pi * 3136 * k * t) * 0.18 + sin(2 * .pi * 4699 * k * t) * 0.1) * exp(-t * 12)
                return zap + click + sparkle
            })
        }
        // 6: Pamuk Şeker — yumuşak "pof", baloncuk ve tatlı bir çan
        let candy = [1.0, 1.12, 1.26].map { k in
            wav(tone(0.5) { t in
                let pof = noise() * exp(-t * 34) * min(1, t * 160) * 0.22
                let bubble = sin(2 * .pi * k * (340 * t + 520 * (1 - exp(-16 * t)) / 16)) * exp(-t * 14) * min(1, t * 220) * 0.42
                let f = 1568.0 * k
                let bell = (sin(2 * .pi * f * t) * 0.24 + sin(2 * .pi * f * 2.0 * t) * 0.07) * exp(-t * 6.5) * min(1, t * 90)
                return pof + bubble + bell
            })
        }
        cutBank = [glass, ice, wood, marimba, nova, flowCut, candy]
        // Akortlu nota paleti (do majör pentatonik, iki oktav)
        noteBank = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21].map { semi in
            let f = 523.25 * pow(2, Double(semi) / 12)
            return wav(tone(0.75) { t in
                let env = exp(-t * 4.8) * min(1, t * 400)
                return (0.6 * sin(2 * .pi * f * t) + 0.22 * sin(2 * .pi * f * 2.01 * t) * exp(-t * 6) + 0.1 * sin(2 * .pi * f * 3 * t)) * env * 0.55
            })
        }
        bank[.perfect] = [wav(tone(1.3) { t in
            var s = 0.0
            for (i, f) in [1046.5, 1318.5, 1568.0, 2093.0, 2637.0].enumerated() {
                let local = t - Double(i) * 0.065
                if local >= 0 { s += sin(2 * .pi * f * local) * exp(-local * 3.6) * 0.22 + sin(2 * .pi * f * 2.003 * local) * exp(-local * 9) * 0.07 }
            }
            return s + noise() * exp(-t * 14) * 0.05
        })]
        bank[.win] = [wav(tone(1.1) { t in
            var s = 0.0
            for (i, f) in [523.25, 659.25, 783.99, 1046.5].enumerated() {
                let local = t - Double(i) * 0.11
                if local >= 0 { s += sin(2 * .pi * f * local) * exp(-local * 4.5) * 0.28 }
            }
            return s
        })]
        bank[.fail] = [wav(tone(0.45) { t in
            let phase = 2 * .pi * 190 / 2.2 * (1 - exp(-2.2 * t))
            return sin(phase) * exp(-t * 6) * 0.6
        })]
        bank[.tap] = [wav(tone(0.09) { t in sin(2 * .pi * 880 * t) * exp(-t * 40) * 0.5 })]
        bank[.deny] = [wav(tone(0.16) { t in
            (sin(2 * .pi * 150 * t) + 0.5 * sin(2 * .pi * 300 * t)) * exp(-t * 18) * 0.4
        })]
    }

    /// i. nota (0-9): düşen parçalar sırayla yükselen notalar çalar.
    func playNote(_ i: Int) {
        guard Prefs.sfxOn, !noteBank.isEmpty, let p = try? AVAudioPlayer(data: noteBank[min(max(i, 0), noteBank.count - 1)]) else { return }
        active.removeAll { !$0.isPlaying }
        active.append(p)
        p.volume = 0.7
        p.play()
    }

    func play(_ kind: SFXKind, semitones: Double = 0) {
        guard Prefs.sfxOn else { return }
        let source = kind == .cut ? cutBank[min(max(season, 0), cutBank.count - 1)] : bank[kind]
        guard let data = source?.randomElement(), let p = try? AVAudioPlayer(data: data) else { return }
        active.removeAll { !$0.isPlaying }
        active.append(p)
        p.volume = 0.8
        if semitones != 0 {
            p.enableRate = true
            p.rate = Float(min(2, max(0.5, pow(2, semitones / 12))))
        }
        p.play()
    }

    private func tone(_ duration: Double, _ f: (Double) -> Double) -> [Float] {
        let n = Int(duration * rate)
        return (0..<n).map { Float(f(Double($0) / rate)) }
    }

    private func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!)
        u32(UInt32(36 + samples.count * 2))
        d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!)
        u32(UInt32(samples.count * 2))
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * 32000)
            u16(UInt16(bitPattern: v))
        }
        return d
    }
}
