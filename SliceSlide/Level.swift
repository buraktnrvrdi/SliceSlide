import CoreGraphics
import Foundation

struct Obstacle {
    var center: CGPoint   // birim koordinat
    var radius: CGFloat
}

struct LevelDef {
    let number: Int
    let shape: [CGPoint]          // birim koordinat, çevrel yarıçap = 1
    let cuts: Int
    let targets: [CGFloat]        // soldan sağa hedef alan oranları
    let tolerance: CGFloat        // mutlak oran sapması (0.05 = %5)
    let obstacles: [Obstacle]
    let timeLimit: TimeInterval?
    let showsPreview: Bool
    let spin: Double              // rad/sn, ilk kesime kadar
    let orbitAmp: CGFloat         // çekirdek yörünge genliği (birim)
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum ShapeKind: CaseIterable {
    case square, wideRect, tallRect, triangle, diamond, pentagon, hexagon, octagon, trapezoid, parallelogram

    func points() -> [CGPoint] {
        func regular(_ n: Int, _ start: Double) -> [CGPoint] {
            (0..<n).map { i in
                let a = start + Double(i) * 2 * .pi / Double(n)
                return CGPoint(x: cos(a), y: sin(a))
            }
        }
        switch self {
        case .square: return [CGPoint(x: -0.8, y: 0.8), CGPoint(x: 0.8, y: 0.8), CGPoint(x: 0.8, y: -0.8), CGPoint(x: -0.8, y: -0.8)]
        case .wideRect: return [CGPoint(x: -1, y: 0.62), CGPoint(x: 1, y: 0.62), CGPoint(x: 1, y: -0.62), CGPoint(x: -1, y: -0.62)]
        case .tallRect: return [CGPoint(x: -0.62, y: 1), CGPoint(x: 0.62, y: 1), CGPoint(x: 0.62, y: -1), CGPoint(x: -0.62, y: -1)]
        case .triangle: return regular(3, .pi / 2)
        case .diamond: return [CGPoint(x: 0, y: 1), CGPoint(x: 0.75, y: 0), CGPoint(x: 0, y: -1), CGPoint(x: -0.75, y: 0)]
        case .pentagon: return regular(5, .pi / 2)
        case .hexagon: return regular(6, .pi / 2)
        case .octagon: return regular(8, .pi / 8)
        case .trapezoid: return [CGPoint(x: -0.55, y: 0.7), CGPoint(x: 0.55, y: 0.7), CGPoint(x: 1, y: -0.7), CGPoint(x: -1, y: -0.7)]
        case .parallelogram: return [CGPoint(x: -0.6, y: 0.65), CGPoint(x: 1, y: 0.65), CGPoint(x: 0.6, y: -0.65), CGPoint(x: -1, y: -0.65)]
        }
    }
}

enum LevelFactory {
    static let totalLevels = Season.levelsPer * 5

    static func make(_ n: Int) -> LevelDef {
        var rng = SeededRNG(seed: UInt64(n) &* 7919)
        let s = (n - 1) / Season.levelsPer          // sezon (0-4)
        let l = (n - 1) % Season.levelsPer + 1      // sezon içi bölüm (1-60)
        let d = l + 14 * s                          // zorluk indeksi: her sezon bir öncekinden biraz yukarıdan başlar

        // Kesim hakkı
        let cuts: Int
        switch d {
        case ..<21: cuts = 1
        case 21...40: cuts = (d % 2 == 1) ? 2 : 1
        default: cuts = (d >= 75 && d % 3 == 0) ? 3 : (d % 4 == 0 ? 1 : 2)
        }

        // Hedef oranları: yavaş yavaş dengesizleşir
        var pool: [[CGFloat]]
        switch cuts {
        case 1:
            if d <= 3 { pool = [[0.5, 0.5]] }
            else if d <= 5 { pool = [[0.5, 0.5], [0.4, 0.6]] }
            else if d <= 10 { pool = [[0.5, 0.5], [0.45, 0.55], [0.4, 0.6]] }
            else if d <= 20 { pool = [[0.4, 0.6], [0.35, 0.65], [0.3, 0.7]] }
            else if d <= 40 { pool = [[0.4, 0.6], [0.3, 0.7], [0.25, 0.75]] }
            else { pool = [[0.35, 0.65], [0.25, 0.75], [0.2, 0.8], [0.15, 0.85]] }
        case 2:
            if d <= 40 { pool = [[1.0 / 3, 1.0 / 3, 1.0 / 3], [0.25, 0.5, 0.25], [0.4, 0.2, 0.4]] }
            else { pool = [[0.2, 0.3, 0.5], [0.25, 0.25, 0.5], [0.4, 0.2, 0.4], [0.15, 0.35, 0.5], [0.3, 0.5, 0.2]] }
        default:
            pool = [[0.25, 0.25, 0.25, 0.25], [0.1, 0.2, 0.3, 0.4], [0.15, 0.35, 0.35, 0.15], [0.4, 0.1, 0.1, 0.4]]
        }
        var targets = pool.randomElement(using: &rng)!
        if rng.next() % 2 == 0 { targets.reverse() }

        // Şekil
        let kinds: [ShapeKind]
        if d <= 10 { kinds = [.square, .wideRect, .tallRect] }
        else if d <= 20 { kinds = [.square, .wideRect, .tallRect, .hexagon, .diamond] }
        else if d <= 40 { kinds = [.hexagon, .square, .wideRect, .pentagon, .diamond, .tallRect, .trapezoid] }
        else { kinds = ShapeKind.allCases }
        let kind = kinds.randomElement(using: &rng)!

        var angle = 0.0
        if d >= 50 { angle = Double.random(in: 0..<Double.pi, using: &rng) }
        else if d >= 35 { angle = [0, Double.pi / 6, Double.pi / 4].randomElement(using: &rng)! }

        var pts = kind.points().map { p -> CGPoint in
            CGPoint(x: p.x * cos(angle) - p.y * sin(angle), y: p.x * sin(angle) + p.y * cos(angle))
        }
        let maxR = pts.map { $0.length }.max() ?? 1
        pts = pts.map { $0 * (1 / maxR) }

        // Tolerans: önizleme kalkınca önce geniş, sonra yavaşça daralır
        var tol: CGFloat
        if d <= 5 { tol = 0.10 }
        else if d <= 10 { tol = 0.12 - 0.004 * CGFloat(d - 6) }
        else if d <= 20 { tol = 0.10 - 0.002 * CGFloat(d - 10) }
        else if d <= 40 { tol = 0.08 - 0.001 * CGFloat(d - 20) }
        else { tol = max(0.035, 0.06 - 0.0005 * CGFloat(d - 40)) }
        tol += 0.004 * CGFloat(s)   // sezon mekaniği hedeflemeyi zorlaştırır

        // Sezon mekanikleri: sezonun ilk 5 bölümü sakin, 6. bölümde başlar ve yavaşça artar
        let prog = CGFloat(max(0, l - 6)) / 54
        var orbit: CGFloat = 0
        var spin = 0.0
        if (s == 1 || s == 4) && l >= 6 { orbit = (s == 1 ? 0.04 : 0.06) + 0.08 * prog }
        if (s == 2 || s == 4) && l >= 6 {
            spin = Double(0.22 + 0.4 * prog) * (s == 4 ? 0.8 : 1) * (n % 2 == 0 ? 1 : -1)
        }

        // Kesilemeyen çekirdekler
        var obstacles: [Obstacle] = []
        let forced = (s == 1 || s == 4) && l >= 6
        if forced || (d >= 16 && d % 4 != 1) {
            var count = (d >= 60 && d % 3 == 0) ? 2 : 1
            if s == 1 { count = l >= 36 ? 2 : 1 }
            if s == 4 { count = l >= 30 ? 2 : 1 }
            let r: CGFloat = 0.12
            var attempts = 0
            while obstacles.count < count && attempts < 80 {
                attempts += 1
                let a = Double.random(in: 0..<(2 * Double.pi), using: &rng)
                let dist = CGFloat.random(in: 0.3...0.55, using: &rng)
                let c = CGPoint(x: cos(a) * dist, y: sin(a) * dist)
                guard Geo.contains(pts, c), Geo.distanceToEdges(pts, c) > r + 0.08 + orbit else { continue }
                if obstacles.contains(where: { ($0.center - c).length < 0.5 }) { continue }
                obstacles.append(Obstacle(center: c, radius: r))
            }
        }

        // Süre
        var timeLimit: TimeInterval? = nil
        if s == 3 && l >= 6 && l % 5 != 0 { timeLimit = TimeInterval(10 + cuts * 5) }
        if s == 4 && l >= 10 && l % 3 != 0 { timeLimit = TimeInterval(9 + cuts * 5) }

        return LevelDef(number: n, shape: pts, cuts: cuts, targets: targets, tolerance: tol,
                        obstacles: obstacles, timeLimit: timeLimit, showsPreview: s == 0 && l <= 5,
                        spin: spin, orbitAmp: orbit)
    }
}
