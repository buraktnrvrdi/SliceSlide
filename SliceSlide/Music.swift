import AVFoundation
import Foundation

/// Ses/müzik tercihleri (UserDefaults; arayüzde @AppStorage ile aynı anahtarlar).
enum Prefs {
    static var musicOn: Bool { UserDefaults.standard.object(forKey: "musicOn") as? Bool ?? true }
    static var sfxOn: Bool { UserDefaults.standard.object(forKey: "sfxOn") as? Bool ?? true }
    static var hapticsOn: Bool { UserDefaults.standard.object(forKey: "hapticsOn") as? Bool ?? true }
    static var notifyOn: Bool { UserDefaults.standard.object(forKey: "notifyOn") as? Bool ?? true }
}

/// Her sezon için döngüde çalan, kodla üretilmiş ambiyans müziği.
final class Music {
    static let shared = Music()
    private var players: [Int: AVAudioPlayer] = [:]
    private var current = -1
    private var generating = Set<Int>()
    private let queue = DispatchQueue(label: "music.gen", qos: .userInitiated)
    private let volume: Float = 0.42
    private var lastEnabled = Prefs.musicOn

    private init() {
        // Müzik tercihi herhangi bir ekrandan değişse bile durumu eşitle.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let on = Prefs.musicOn
            if on != self.lastEnabled { self.lastEnabled = on; self.refresh() }
        }
    }

    func play(season requested: Int) {
        // Tema setinin kendi müziği var (Akış Modu kendi temposunu korur)
        let season = requested == 5 ? 5 : (ThemeSet.active?.music ?? requested)
        let old = current
        current = season
        guard Prefs.musicOn else { stopAll(); return }
        if old == season, players[season]?.isPlaying == true { return }
        if let p = players[season] {
            start(p)
            if old >= 0, old != season { fadeOut(old) }
            return
        }
        guard generating.insert(season).inserted else { return }
        queue.async { [weak self] in
            let data = MusicSynth.track(season)
            DispatchQueue.main.async {
                guard let self else { return }
                self.generating.remove(season)
                guard let p = try? AVAudioPlayer(data: data) else { return }
                p.numberOfLoops = -1
                p.enableRate = true
                p.prepareToPlay()
                self.players[season] = p
                if self.current == season && Prefs.musicOn {
                    self.start(p)
                    if old >= 0, old != season { self.fadeOut(old) }
                }
            }
        }
    }

    /// Seri arttıkça müzik hafifçe hızlanır (1.0 → ~1.18).
    func setIntensity(_ combo: Int) {
        guard Prefs.musicOn else { return }
        let r = Float(1 + 0.03 * Double(min(max(combo, 0), 6)))
        for p in players.values where p.isPlaying { p.rate = r }
    }

    /// Ayar değişince çağrılır.
    func refresh() {
        lastEnabled = Prefs.musicOn
        if Prefs.musicOn {
            if current >= 0 { play(season: current) }
        } else {
            stopAll()
        }
    }

    /// Hiçbir parça çalmasın: kısa bir kısılmadan sonra hepsi durdurulur.
    private func stopAll() {
        for p in players.values where p.isPlaying { p.setVolume(0, fadeDuration: 0.25) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, !Prefs.musicOn else { return }
            for p in self.players.values { p.pause() }
        }
    }

    private func start(_ p: AVAudioPlayer) {
        guard Prefs.musicOn else { return }
        if !p.isPlaying { p.volume = 0; p.play() }
        p.setVolume(volume, fadeDuration: 1.6)
    }

    private func fadeOut(_ i: Int) {
        guard let p = players[i] else { return }
        p.setVolume(0, fadeDuration: 1.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            if self?.current != i || !Prefs.musicOn { p.pause() }
        }
    }
}

enum MusicSynth {
    static let rate = 16000.0

    private static func hz(_ root: Double, _ semis: Double) -> Double { root * pow(2, semis / 12) }

    static func track(_ s: Int) -> Data {
        let dur: Double = [24, 24, 24, 20, 24, 16, 24][min(max(s, 0), 6)]
        let n = Int(dur * rate)
        var buf = [Float](repeating: 0, count: n)
        var rng = SeededRNG(seed: UInt64(s) &* 977 &+ 11)

        // Kind: 0 çan, 1 pad, 2 pluck, 3 flüt, 4 sentez pad, 5 davul
        func note(_ f: Double, _ t0: Double, _ len: Double, _ amp: Float, _ kind: Int) {
            let tail = kind == 0 || kind == 9 ? 3.0 : (kind >= 5 ? 0.4 : 0.6)
            let total = Int((len + tail) * rate)
            let start = Int(t0 * rate)
            for i in 0..<total {
                let t = Double(i) / rate
                var v = 0.0
                switch kind {
                case 0:
                    v = (0.6 * sin(2 * .pi * f * t) + 0.25 * sin(2 * .pi * f * 2.76 * t) + 0.12 * sin(2 * .pi * f * 5.4 * t)) * exp(-t * 2.2)
                    v *= min(1, t * 200)
                case 1:
                    let env = pow(sin(.pi * min(t / len, 1)), 2) * (t <= len ? 1 : exp(-(t - len) * 8))
                    v = (sin(2 * .pi * f * t) + 0.5 * sin(2 * .pi * f * 1.004 * t) + 0.25 * sin(2 * .pi * f * 2 * t)) * env * 0.5
                case 2:
                    v = (sin(2 * .pi * f * t) + 0.5 * sin(2 * .pi * f * 2 * t) + 0.3 * sin(2 * .pi * f * 3 * t)) * exp(-t * 5) * 0.6
                    v *= min(1, t * 300)
                case 3:
                    let vib = 0.006 * sin(2 * .pi * 5.2 * t) * min(1, t * 2)
                    let env = min(1, t * 6) * (t <= len ? 1 : exp(-(t - len) * 9)) * (0.7 + 0.3 * sin(.pi * min(t / len, 1)))
                    v = (sin(2 * .pi * f * t + vib * f * 0.05) + 0.2 * sin(4 * .pi * f * t)) * env * 0.7
                case 4:
                    let env = pow(sin(.pi * min(t / len, 1)), 1.5) * (t <= len ? 1 : exp(-(t - len) * 8))
                    var saw = 0.0
                    for k in 1...5 { saw += sin(2 * .pi * f * Double(k) * t) / Double(k) + sin(2 * .pi * f * 1.006 * Double(k) * t) / Double(k) }
                    v = saw * env * 0.22
                case 9: // müzik kutusu / kalimba
                    v = (0.62 * sin(2 * .pi * f * t) + 0.2 * sin(2 * .pi * f * 2 * t) * exp(-t * 4) + 0.1 * sin(2 * .pi * f * 4.07 * t) * exp(-t * 9)) * exp(-t * 2.6)
                    v *= min(1, t * 260)
                case 6: // hi-hat
                    v = Double.random(in: -1...1, using: &rng) * exp(-t * 70)
                case 7: // klap
                    v = Double.random(in: -1...1, using: &rng) * exp(-t * 22) * min(1, t * 400)
                case 8: // bas (testere benzeri, kısa)
                    var saw = 0.0
                    for k in 1...4 { saw += sin(2 * .pi * f * Double(k) * t) / Double(k) }
                    v = saw * exp(-t * 5) * 0.5 * min(1, t * 300)
                default:
                    let fr = 50 + 70 * exp(-t * 18)
                    v = sin(2 * .pi * fr * t) * exp(-t * 7)
                }
                buf[(start + i) % n] += Float(v) * amp
            }
        }

        func bellWithEcho(_ f: Double, _ t: Double, _ amp: Float) {
            note(f, t, 0.1, amp, 0)
            note(f, t + 0.45, 0.1, amp * 0.4, 0)
            note(f, t + 0.9, 0.1, amp * 0.18, 0)
        }

        switch s {
        case 0: // Kristal Vadisi: Do majör, bell arpej
            let root = 130.81
            let chords: [[Double]] = [[0, 4, 7, 11], [-3, 0, 4, 7], [-7, -3, 0, 4], [-5, -1, 2, 5]]
            for (ci, c) in chords.enumerated() { for st in c { note(hz(root, st), Double(ci) * 6, 6, 0.10, 1) } }
            let pent: [Double] = [0, 2, 4, 7, 9, 12, 14, 16, 19]
            var t = 0.4
            while t < dur - 1 {
                note(hz(root * 2, pent.randomElement(using: &rng)!), t, 0.1, 0.16, 0)
                t += Double.random(in: 0.7...1.6, using: &rng)
            }
        case 1: // Buz Mağarası: re minör, seyrek ve yankılı
            let root = 146.83
            let chords: [[Double]] = [[0, 3, 7, 10, 14], [-4, 0, 3, 7], [0, 3, 7, 10, 14], [-2, 2, 5, 9]]
            for (ci, c) in chords.enumerated() { for st in c { note(hz(root, st), Double(ci) * 6, 6, 0.08, 1) } }
            let sc: [Double] = [0, 3, 5, 7, 10, 12, 15, 17, 19, 22]
            var t = 0.8
            while t < dur - 3 {
                bellWithEcho(hz(root * 2, sc.randomElement(using: &rng)!), t, 0.13)
                t += Double.random(in: 1.4...3.0, using: &rng)
            }
        case 2: // Amber Çölü: Frigiyen dominant, drone + pluck + davul
            let root = 82.41
            note(hz(root, 0), 0, 24, 0.16, 1); note(hz(root, 7), 0, 24, 0.12, 1); note(hz(root * 2, 0), 0, 24, 0.07, 1)
            let sc: [Double] = [0, 1, 4, 5, 7, 8, 10, 12, 13, 16]
            var t = 0.0
            while t < dur - 0.5 {
                if Double.random(in: 0...1, using: &rng) < 0.78 {
                    note(hz(root * 4, sc.randomElement(using: &rng)!), t, 0.3, 0.22, 2)
                }
                t += [0.375, 0.375, 0.75, 0.5].randomElement(using: &rng)!
            }
            var k = 0.0
            while k < dur { note(60, k, 0.4, 0.34, 5); if Int(k / 1.5) % 2 == 1 { note(60, k + 0.75, 0.4, 0.18, 5) }; k += 1.5 }
        case 3: // Zümrüt Ormanı: Sol majör, flüt + marimba arpej
            let root = 98.0
            let chords: [[Double]] = [[0, 4, 7, 11], [-3, 0, 4, 7], [-7, -3, 0, 4], [-5, -1, 2, 5]]
            for (ci, c) in chords.enumerated() { for st in c { note(hz(root, st), Double(ci) * 5, 5, 0.09, 1) } }
            let pent: [Double] = [0, 2, 4, 7, 9, 12, 14, 16]
            var t = 0.5
            while t < dur - 1.5 {
                let l = Double.random(in: 0.5...1.3, using: &rng)
                note(hz(root * 4, pent.randomElement(using: &rng)!), t, l, 0.22, 3)
                t += l + Double.random(in: 0.1...0.6, using: &rng)
            }
            var a = 0.0
            let arp: [Double] = [0, 7, 12, 16, 12, 7]
            var ai = 0
            while a < dur - 0.3 {
                note(hz(root * 2, arp[ai % arp.count] + [0, -3, -7, -5][Int(a / 5) % 4]), a, 0.1, 0.08, 0)
                ai += 1; a += 0.5
            }
        case 6: // Pamuk Şeker: Fa majör ninni, müzik kutusu + kalimba + yumuşak pad
            let root = 174.61   // Fa
            let chords: [[Double]] = [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]]   // F, Dm, Bb, C
            for (ci, c) in chords.enumerated() { for st in c { note(hz(root / 2, st), Double(ci) * 6, 6, 0.06, 1) } }
            let step = 0.375
            let arp = [0, 1, 2, 1, 2, 1, 0, 2]
            for ci in 0..<4 {                                                            // kalimba arpej
                for e in 0..<16 {
                    let c = chords[ci]
                    note(hz(root, c[arp[e % arp.count]]), Double(ci) * 6 + Double(e) * step, 0.1, e % 4 == 0 ? 0.10 : 0.065, 9)
                }
            }
            // Müzik kutusu melodisi (yarım vuruş birimleriyle)
            let melody: [(Double, Double)] = [
                (12, 2), (16, 2), (19, 2), (16, 2), (14, 4), (12, 4),
                (9, 2), (12, 2), (16, 4), (14, 2), (12, 2), (9, 4),
                (5, 2), (9, 2), (12, 4), (14, 2), (12, 2), (9, 2), (7, 2),
                (7, 2), (11, 2), (14, 4), (12, 4), (11, 2), (14, 2),
            ]
            var t = 0.0
            for (st, beats) in melody where t < dur - 0.2 {
                note(hz(root * 2, st), t, 0.1, 0.17, 9)
                note(hz(root * 4, st), t + 0.02, 0.1, 0.035, 0)                        // ince parıltı
                t += beats * step
            }
        case 5: // Akış Modu: enerjik elektronik, 120 BPM
            let beat = 0.5
            let root = 55.0   // La
            let roots: [Double] = [0, -4, 3, -2]   // Am, F, C, G (4 sn'lik bölümler)
            let chords: [[Double]] = [[12, 15, 19], [8, 12, 15], [15, 19, 22], [10, 14, 17]]
            for bar in 0..<4 {
                let t0 = Double(bar) * 4
                for st in chords[bar] { note(hz(root * 4, st), t0, 4, 0.05, 4) }          // pad
                for e in 0..<8 {                                                          // bas, sekizlikler
                    note(hz(root * 2, roots[bar]), t0 + Double(e) * beat * 0.5, 0.2, e % 2 == 0 ? 0.32 : 0.2, 8)
                }
            }
            var b = 0.0
            while b < dur - 0.01 {                                                        // vuruşlar
                note(60, b, 0.3, 0.55, 5)                                                 // kick her vuruşta
                if Int((b / beat).rounded()) % 2 == 1 { note(0, b, 0.2, 0.22, 7) }       // klap 2 ve 4
                note(0, b + beat * 0.5, 0.05, 0.1, 6)                                     // hi-hat
                b += beat
            }
            let sc: [Double] = [0, 3, 5, 7, 10, 12, 15, 17]
            var t = 0.0, i = 0
            while t < dur - 0.2 {                                                         // 16'lık arpej
                let bar = Int(t / 4) % 4
                if i % 4 != 3 || Double.random(in: 0...1, using: &rng) < 0.5 {
                    note(hz(root * 8, sc[(i * 3 + bar) % sc.count] + roots[bar]), t, 0.1, 0.075, 2)
                }
                i += 1; t += beat * 0.25
            }
        default: // Nova: la minör, sentez pad + bas + hızlı arpej
            let root = 110.0
            let chords: [[Double]] = [[0, 3, 7, 10], [-4, 0, 3, 7], [-9, -5, -2, 2], [-7, -3, 0, 4]]
            for (ci, c) in chords.enumerated() { for st in c { note(hz(root, st), Double(ci) * 6, 6, 0.10, 4) } }
            let bass: [Double] = [-24, -28, -33, -31]
            for ci in 0..<4 { for b in 0..<4 { note(hz(root, bass[ci] + 12), Double(ci) * 6 + Double(b) * 1.5, 1.2, 0.30, 1) } }
            let arp: [Double] = [12, 15, 19, 22, 24, 22, 19, 15]
            var t = 0.0, i = 0
            while t < dur - 0.3 {
                let ci = Int(t / 6) % 4
                note(hz(root, arp[i % arp.count] + [0, -4, -9, -7][ci]), t, 0.1, 0.07, 2)
                i += 1; t += 0.25
            }
        }

        // normalize
        let peak = buf.map { abs($0) }.max() ?? 1
        let g = peak > 0 ? 0.8 / peak : 1
        return wav(buf.map { $0 * g })
    }

    private static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + samples.count * 2))
        d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(UInt32(samples.count * 2))
        for s in samples { u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32000))) }
        return d
    }
}
