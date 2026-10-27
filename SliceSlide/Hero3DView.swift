import SwiftUI
import UIKit

/// Ana menü kahramanı: gerçek 3B geometriyle çizilen cam kristal.
/// SceneKit'e bağlı değildir; SwiftUI Canvas ile perspektif projeksiyon, derinlik sıralaması ve
/// yüzey başına ışıklandırma yapar. Sürekli döner, periyodik olarak ışık diskiyle kesilip ayrılır.
struct Hero3DView: View {
    let top: UIColor
    let bottom: UIColor
    @State private var tapAt = Date.distantPast

    private static let faces = GemGeometry.faces()

    var body: some View {
        // Daha doygun, derin bir renk geçişi (açık pastel üst tonu aşağıya doğru çeker)
        let topRGB = RGB(top).mixed(RGB(bottom), 0.5)
        let bottomRGB = RGB(bottom).scaled(0.86)
        return TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let tapDt = ctx.date.timeIntervalSince(tapAt)
            Canvas(rendersAsynchronously: true) { gc, size in
                GemRenderer.draw(&gc, size: size, t: t, tapDt: tapDt,
                                 faces: Self.faces, top: topRGB, bottom: bottomRGB)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard Date().timeIntervalSince(tapAt) > 1.2 else { return }
            tapAt = Date()
            Haptics.tap()
            SFX.shared.play(.tap)
        }
    }
}

// MARK: - Geometri

struct RGB {
    var r: Double, g: Double, b: Double
    init(_ c: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = r; self.g = g; self.b = b
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    func mixed(_ o: RGB, _ t: Double) -> RGB { RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t) }
    func scaled(_ k: Double) -> RGB { RGB(r: min(1, r * k), g: min(1, g * k), b: min(1, b * k)) }
    func added(_ k: Double) -> RGB { RGB(r: min(1, r + k), g: min(1, g + k), b: min(1, b + k)) }
    var color: Color { Color(red: r, green: g, blue: b) }
}

typealias V3 = SIMD3<Double>

struct GemFace {
    var pts: [V3]
    var normal: V3
    var centroid: V3
    var upperHalf: Bool
    var isCap: Bool
    var shade: Double       // 0 (üst) … 1 (alt)
}

enum GemGeometry {
    static let topY = 1.30, bottomY = -1.55

    static func faces() -> [GemFace] {
        var out: [GemFace] = []
        for upper in [true, false] {
            let ys: [Double] = upper ? [1.30, 0.82, 0.34, 0.0] : [-1.55, -0.98, -0.38, 0.0]
            let rs: [Double] = [0.0, 0.50, 1.0, 1.0]
            let rot: [Double] = [0, .pi / 6, 0, 0]
            func ring(_ i: Int) -> [V3] {
                (0..<6).map { k in
                    let a = rot[i] + Double(k) * .pi / 3
                    return V3(rs[i] * cos(a), ys[i], rs[i] * sin(a))
                }
            }
            let r0 = ring(0), r1 = ring(1), r2 = ring(2), r3 = ring(3)

            func add(_ p: [V3], cap: Bool = false) {
                var pts = p
                let c = pts.reduce(V3.zero, +) / Double(pts.count)
                var n = cross(pts[1] - pts[0], pts[2] - pts[0])
                let l = max((n * n).sum().squareRoot(), 1e-9)
                n /= l
                let outward = cap ? V3(0, upper ? -1 : 1, 0) : c
                if dot(n, outward) < 0 { n = -n; pts.reverse() }
                let shade = min(max((topY - c.y) / (topY - bottomY), 0), 1)
                out.append(GemFace(pts: pts, normal: n, centroid: c, upperHalf: upper, isCap: cap, shade: shade))
            }

            for k in 0..<6 { add([r0[0], r1[k], r1[(k + 1) % 6]]) }
            for k in 0..<6 {
                add([r1[k], r2[k], r2[(k + 1) % 6]])
                add([r2[(k + 1) % 6], r1[(k + 1) % 6], r1[k]])
            }
            for k in 0..<6 { add([r2[k], r3[k], r3[(k + 1) % 6], r2[(k + 1) % 6]]) }
            add(r3, cap: true)   // kesim yüzeyi (altıgen)
        }
        return out
    }

    static func dot(_ a: V3, _ b: V3) -> Double { (a * b).sum() }
    static func cross(_ a: V3, _ b: V3) -> V3 {
        V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
}

// MARK: - Çizim

enum GemRenderer {
    static let cycle = 6.5

    static func ease(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * (3 - 2 * c) }
    static func easeOut(_ x: Double) -> Double { let c = min(max(x, 0), 1); return 1 - pow(1 - c, 3) }

    /// Kesim döngüsü: ayrılma (0…1), ışık diski yoğunluğu ve ölçeği.
    static func phase(_ T: Double) -> (sep: Double, disc: Double, discScale: Double) {
        var sep = 0.0, disc = 0.0, scale = 0.0
        switch T {
        case 2.2..<2.7:
            let p = (T - 2.2) / 0.5
            disc = ease(p); scale = easeOut(p) * 1.2
        case 2.7..<4.9:
            scale = 1.2
            disc = max(0.0, 1 - ease((T - 2.7) / 2.2)) * 0.85 + 0.12 * (1 - ease((T - 2.7) / 2.2))
        default: break
        }
        switch T {
        case 2.6..<3.3: sep = easeOut((T - 2.6) / 0.7)
        case 3.3..<4.9: sep = 1
        case 4.9..<5.8: sep = 1 - ease((T - 4.9) / 0.9)
        default: sep = 0
        }
        return (sep, disc, scale)
    }

    static func draw(_ gc: inout GraphicsContext, size: CGSize, t: Double, tapDt: Double,
                     faces: [GemFace], top: RGB, bottom: RGB) {
        let T = t.truncatingRemainder(dividingBy: cycle)
        let (sep, discA, discScale) = phase(T)
        let bob = sin(t * 1.5) * 0.05

        let unit = min(size.width / 2.7, size.height / 4.45)
        let cx = size.width / 2, cy = size.height / 2
        let tilt = 0.30 + 0.06 * sin(t * 0.8)
        let camZ = 6.0, focal = 6.0
        var yaw = t * 0.55 + 0.35 * sin(t * 0.7)
        if tapDt >= 0, tapDt < 1.2 { yaw += ease(tapDt / 1.2) * 2 * .pi }
        let squash = tapDt >= 0 && tapDt < 1.2 ? 1 + 0.06 * sin(.pi * tapDt / 1.2) : 1.0

        func project(_ p: V3) -> (pt: CGPoint, z: Double, v: V3) {
            // eğim (X ekseni)
            let y2 = p.y * cos(tilt) - p.z * sin(tilt)
            let z2 = p.y * sin(tilt) + p.z * cos(tilt)
            let d = camZ - z2
            let s = focal / d * squash
            return (CGPoint(x: cx + p.x * unit * s, y: cy - y2 * unit * s), z2, V3(p.x, y2, z2))
        }
        func rotY(_ p: V3, _ a: Double) -> V3 {
            V3(p.x * cos(a) + p.z * sin(a), p.y, -p.x * sin(a) + p.z * cos(a))
        }
        func tiltN(_ n: V3) -> V3 {
            V3(n.x, n.y * cos(tilt) - n.z * sin(tilt), n.y * sin(tilt) + n.z * cos(tilt))
        }

        // arka parıltı + zemin gölgesi (filtre yok, yalnızca gradyan)
        gc.fill(Path(ellipseIn: CGRect(x: cx - unit * 1.5, y: cy - unit * 1.7, width: unit * 3.0, height: unit * 3.4)),
                with: .radialGradient(Gradient(colors: [.white.opacity(0.30), .white.opacity(0)]),
                                      center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: unit * 1.6))
        do {
            let w = unit * 1.0 * (1 - sep * 0.12)
            let c = CGPoint(x: cx, y: cy + unit * 1.72)
            var s = gc
            s.translateBy(x: c.x, y: c.y)
            s.scaleBy(x: 1, y: 0.2)
            s.fill(Path(ellipseIn: CGRect(x: -w, y: -w, width: w * 2, height: w * 2)),
                   with: .radialGradient(Gradient(colors: [.black.opacity(0.17), .black.opacity(0)]),
                                         center: .zero, startRadius: 0, endRadius: w))
        }

        let la = t * 0.9
        let light = normalize(V3(-0.5 + 0.55 * cos(la), 0.75, 0.55 + 0.35 * sin(la)))
        let half = normalize(light + V3(0, 0, 1))

        struct Drawn { var path: Path; var color: Color; var z: Double; var stroke: Color; var upper: Bool }
        var drawn: [Drawn] = []
        let twist = sep * 0.45

        for f in faces {
            let a = yaw + (f.upperHalf ? twist : -twist)
            let off = (f.upperHalf ? 1 : -1) * sep * 0.52 + bob
            let rotated = f.pts.map { p -> V3 in var q = rotY(p, a); q.y += off; return q }
            let nW = rotY(f.normal, a)
            let nV = tiltN(nW)
            let cW = rotY(f.centroid, a) + V3(0, off, 0)
            let cP = project(cW)
            // arka yüz ayıklama
            let toCam = normalize(V3(0, 0, camZ) - cP.v)
            if GemGeometry.dot(nV, toCam) <= 0 { continue }

            var path = Path()
            for (i, p) in rotated.enumerated() {
                let pr = project(p).pt
                if i == 0 { path.move(to: pr) } else { path.addLine(to: pr) }
            }
            path.closeSubpath()

            let base = top.mixed(bottom, f.shade)
            var col: RGB
            if f.isCap {
                col = base.mixed(RGB(r: 1, g: 1, b: 1), 0.5).added(0.04)
            } else {
                let diff = max(0, GemGeometry.dot(nV, light))
                let spec = pow(max(0, GemGeometry.dot(nV, half)), 36)
                // kenara yakın yüzeylerde hafif fresnel parlaması
                let rim = pow(1 - max(0, GemGeometry.dot(nV, V3(0, 0, 1))), 2.2) * 0.18
                col = base.scaled(0.58 + 0.48 * diff).added(spec * 0.42 + rim)
            }
            drawn.append(Drawn(path: path, color: col.color, z: cP.z, stroke: .white.opacity(f.isCap ? 0.0 : 0.30), upper: f.upperHalf))
        }

        // derinlik sıralaması: uzaktan yakına
        drawn.sort { $0.z < $1.z }

        func paint(_ l: inout GraphicsContext, _ items: [Drawn]) {
            for d in items {
                l.fill(d.path, with: .color(d.color))
                l.stroke(d.path, with: .color(d.color), lineWidth: 0.8)       // dikiş boşluklarını kapatır
                l.stroke(d.path, with: .color(d.stroke), lineWidth: 0.9)
            }
        }

        // Katman: alt yarı → ışık diski → üst yarı (üstten bakıldığı için)
        paint(&gc, drawn.filter { !$0.upper })

        if discA > 0.001 {
            gc.drawLayer { l in
                l.blendMode = .plusLighter
                let R = 1.45 * discScale * unit
                l.translateBy(x: cx, y: cy + bob * unit)
                l.scaleBy(x: 1, y: sin(tilt) * 1.05)
                let g = Gradient(stops: [.init(color: .white.opacity(discA), location: 0),
                                         .init(color: .white.opacity(discA * 0.35), location: 0.4),
                                         .init(color: .white.opacity(0), location: 1)])
                l.fill(Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2)),
                       with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: R))
            }
        }

        paint(&gc, drawn.filter { $0.upper })

        // kıvılcımlar (ayrılma anında)
        let tau = T - 2.6
        if tau >= 0, tau < 1.4 {
            var rng = SeededRNG(seed: 91)
            for _ in 0..<18 {
                let ang = Double.random(in: 0..<(2 * .pi), using: &rng)
                let speed = Double.random(in: 0.9...2.2, using: &rng)
                let r = speed * easeOut(tau / 1.4)
                let p = V3(cos(ang) * r, 0.02, sin(ang) * r)
                let pr = project(p)
                let alpha = 1 - ease(tau / 1.4)
                let s = CGFloat(Double.random(in: 1.6...3.6, using: &rng))
                let halo = s * 2.4
                gc.fill(Path(ellipseIn: CGRect(x: pr.pt.x - halo, y: pr.pt.y - halo, width: halo * 2, height: halo * 2)),
                        with: .color(.white.opacity(alpha * 0.22)))
                gc.fill(Path(ellipseIn: CGRect(x: pr.pt.x - s, y: pr.pt.y - s, width: s * 2, height: s * 2)),
                        with: .color(.white.opacity(alpha)))
            }
        }
    }

    static func normalize(_ v: V3) -> V3 {
        let l = max((v * v).sum().squareRoot(), 1e-9)
        return v / l
    }
}
