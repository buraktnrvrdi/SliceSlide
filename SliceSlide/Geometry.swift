import CoreGraphics

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    var length: CGFloat { hypot(x, y) }
    var unit: CGPoint {
        let l = length
        return l > 0 ? CGPoint(x: x / l, y: y / l) : .zero
    }
}

enum Geo {
    /// Yönlü sonsuz doğru. `side > 0` doğrunun solundadır.
    struct Line {
        var p: CGPoint
        var d: CGPoint
        func side(_ q: CGPoint) -> CGFloat { d.x * (q.y - p.y) - d.y * (q.x - p.x) }
        var leftNormal: CGPoint { CGPoint(x: -d.y, y: d.x) }
    }

    struct Split {
        var left: [CGPoint]
        var right: [CGPoint]
        var cutA: CGPoint
        var cutB: CGPoint
    }

    static func area(_ poly: [CGPoint]) -> CGFloat {
        var s: CGFloat = 0
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            s += a.x * b.y - b.x * a.y
        }
        return abs(s) / 2
    }

    static func centroid(_ poly: [CGPoint]) -> CGPoint {
        var a: CGFloat = 0, cx: CGFloat = 0, cy: CGFloat = 0
        for i in poly.indices {
            let p = poly[i], q = poly[(i + 1) % poly.count]
            let cr = p.x * q.y - q.x * p.y
            a += cr
            cx += (p.x + q.x) * cr
            cy += (p.y + q.y) * cr
        }
        a /= 2
        guard abs(a) > 1e-9 else { return poly.first ?? .zero }
        return CGPoint(x: cx / (6 * a), y: cy / (6 * a))
    }

    static func contains(_ poly: [CGPoint], _ pt: CGPoint) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > pt.y) != (b.y > pt.y),
               pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Noktanın çokgen kenarlarına olan en kısa uzaklığı.
    static func distanceToEdges(_ poly: [CGPoint], _ pt: CGPoint) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let ab = b - a
            let len2 = ab.x * ab.x + ab.y * ab.y
            let t = len2 > 0 ? max(0, min(1, ((pt.x - a.x) * ab.x + (pt.y - a.y) * ab.y) / len2)) : 0
            let proj = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
            best = min(best, (pt - proj).length)
        }
        return best
    }

    /// Dışbükey çokgeni doğru boyunca ikiye böler. Doğru çokgeni gerçekten kesmiyorsa nil.
    static func split(_ poly: [CGPoint], by line: Line, minArea: CGFloat = 6) -> Split? {
        let eps: CGFloat = 1e-6
        var left: [CGPoint] = [], right: [CGPoint] = [], hits: [CGPoint] = []
        let n = poly.count
        for i in 0..<n {
            let a = poly[i], b = poly[(i + 1) % n]
            let sa = line.side(a), sb = line.side(b)
            if sa >= -eps { left.append(a) }
            if sa <= eps { right.append(a) }
            if abs(sa) <= eps { hits.append(a) }
            if (sa > eps && sb < -eps) || (sa < -eps && sb > eps) {
                let t = sa / (sa - sb)
                let ip = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                left.append(ip)
                right.append(ip)
                hits.append(ip)
            }
        }
        guard hits.count >= 2, left.count >= 3, right.count >= 3,
              area(left) > minArea, area(right) > minArea else { return nil }
        return Split(left: left, right: right, cutA: hits[0], cutB: hits[hits.count - 1])
    }

    /// Köşeleri yumuşatılmış kapalı yol (yumuşak köşeli kristal görünümü).
    static func roundedPath(_ input: [CGPoint], radius: CGFloat) -> CGPath {
        var pts: [CGPoint] = []
        for p in input where pts.last.map({ ($0 - p).length > 0.5 }) ?? true { pts.append(p) }
        let path = CGMutablePath()
        let n = pts.count
        guard n >= 3 else { return path }
        let m0 = (pts[0] + pts[1]) * 0.5
        path.move(to: m0)
        for i in 1...n {
            let prev = pts[i - 1], v = pts[i % n], next = pts[(i + 1) % n]
            let u = (prev - v), w = (next - v)
            let l1 = u.length, l2 = w.length
            guard l1 > 0.01, l2 > 0.01 else { continue }
            let cosT = max(-1, min(1, (u.x * w.x + u.y * w.y) / (l1 * l2)))
            let half = acos(cosT) / 2
            let r = min(radius, 0.45 * min(l1, l2) * tan(half))
            if r < 0.5 || half < 0.03 {
                path.addLine(to: v)
            } else {
                path.addArc(tangent1End: v, tangent2End: next, radius: r)
            }
        }
        path.closeSubpath()
        return path
    }

    /// Parça alanlarını hedef oranlara en iyi uyacak şekilde eşler (en büyük sapmayı en aza indirir).
    /// Dönüş: parça indeksi -> hedef indeksi.
    static func bestMatch(_ areas: [CGFloat], _ targets: [CGFloat]) -> [Int] {
        let n = areas.count
        guard n == targets.count, n > 0 else { return Array(0..<n) }
        var best = Array(0..<n)
        var bestKey: (CGFloat, CGFloat) = (.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var cur = [Int](), used = [Bool](repeating: false, count: n)
        func rec() {
            if cur.count == n {
                var mx: CGFloat = 0, sum: CGFloat = 0
                for (i, t) in cur.enumerated() { let e = abs(areas[i] - targets[t]); mx = max(mx, e); sum += e }
                if mx < bestKey.0 - 1e-9 || (abs(mx - bestKey.0) <= 1e-9 && sum < bestKey.1) { bestKey = (mx, sum); best = cur }
                return
            }
            for t in 0..<n where !used[t] { used[t] = true; cur.append(t); rec(); cur.removeLast(); used[t] = false }
        }
        rec()
        return best
    }
}
