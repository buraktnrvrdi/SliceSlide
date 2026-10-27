import CoreGraphics
import Foundation

/// İpucu: mevcut durumdan hedefleri tutturan ilk kesim çizgisini arar.
final class HintSolver {
    struct SP {
        var poly: [CGPoint]
        var cores: [(c: CGPoint, r: CGFloat)]
        var tg: [Int]
    }

    private let targets: [CGFloat]
    private let tol: CGFloat
    private let total: CGFloat
    private let deadline: Date
    private var nodes = 0
    private var firstLine: Geo.Line?
    private var rootCuts = 0

    init(targets: [CGFloat], tol: CGFloat, total: CGFloat, timeBudget: TimeInterval = 3) {
        self.targets = targets
        self.tol = tol
        self.total = total
        deadline = Date().addingTimeInterval(timeBudget)
    }

    /// pieces: mevcut parçalar (hedef ataması henüz yok), cutsLeft: kalan kesim hakkı.
    func solve(pieces: [(poly: [CGPoint], cores: [(c: CGPoint, r: CGFloat)])], cutsLeft: Int) -> Geo.Line? {
        guard pieces.count + cutsLeft == targets.count else { return nil }
        rootCuts = cutsLeft
        for assignment in assignments(pieces) {
            let ps = pieces.enumerated().map { SP(poly: $0.element.poly, cores: $0.element.cores, tg: assignment[$0.offset]) }
            if dfs(ps, cutsLeft) { return firstLine }
            if Date() > deadline { return nil }
        }
        return nil
    }

    /// Hedefleri parçalara, alan toplamları tutacak şekilde dağıtır.
    private func assignments(_ pieces: [(poly: [CGPoint], cores: [(c: CGPoint, r: CGFloat)])]) -> [[[Int]]] {
        let k = pieces.count
        let fr = pieces.map { Geo.area($0.poly) / total }
        var out: [[[Int]]] = []
        var cur = [[Int]](repeating: [], count: k)
        func rec(_ t: Int) {
            if out.count >= 24 { return }
            if t == targets.count {
                for i in 0..<k {
                    let sum = cur[i].map { targets[$0] }.reduce(0, +)
                    if cur[i].isEmpty || abs(sum - fr[i]) > tol * CGFloat(cur[i].count) + 0.004 { return }
                }
                out.append(cur)
                return
            }
            for i in 0..<k { cur[i].append(t); rec(t + 1); cur[i].removeLast() }
        }
        rec(0)
        return out
    }

    private func evaluate(_ ps: [SP]) -> Bool {
        guard ps.count == targets.count else { return false }
        let areas = ps.map { Geo.area($0.poly) / total }
        let match = Geo.bestMatch(areas, targets)
        for (i, t) in match.enumerated() where abs(areas[i] - targets[t]) > tol { return false }
        return true
    }

    private func blocked(_ ps: [SP], _ line: Geo.Line) -> Bool {
        for p in ps { for c in p.cores where abs(line.side(c.c)) < c.r + 3 { return true } }
        return false
    }

    private func areaLeft(_ poly: [CGPoint], _ line: Geo.Line) -> CGFloat {
        if let s = Geo.split(poly, by: line, minArea: 0.0001) { return Geo.area(s.left) }
        return line.side(Geo.centroid(poly)) > 0 ? Geo.area(poly) : 0
    }

    private func subsets(_ vals: [CGFloat]) -> [[Int]] {
        var out: [[Int]] = []
        var seen = Set<[Int]>()
        let n = vals.count
        guard n >= 2 else { return [] }
        for m in 1..<((1 << n) - 1) {
            let idx = (0..<n).filter { m & (1 << $0) != 0 }
            let key = idx.map { Int((vals[$0] * 1000).rounded()) }.sorted()
            if seen.insert(key).inserted { out.append(idx) }
        }
        return out
    }

    private func dfs(_ ps: [SP], _ cuts: Int) -> Bool {
        if cuts == 0 { return evaluate(ps) }
        for (i, piece) in ps.enumerated() where piece.tg.count >= 2 {
            let vals = piece.tg.map { targets[$0] }
            let c0 = Geo.centroid(piece.poly)
            let R = piece.poly.map { ($0 - c0).length }.max() ?? 1
            for sub in subsets(vals) {
                let f1 = sub.map { vals[$0] }.reduce(0, +)
                for deg in stride(from: 0.0, to: 360.0, by: 4.0) {
                    let th = CGFloat(deg * .pi / 180)
                    let d = CGPoint(x: cos(th), y: sin(th))
                    let nrm = CGPoint(x: -d.y, y: d.x)
                    for delta in [0.0, 0.4, -0.4] as [CGFloat] {
                        nodes += 1
                        if nodes % 1500 == 0, Date() > deadline { return false }
                        let want = (f1 + delta * tol) * total
                        var lo = -R, hi = R
                        for _ in 0..<36 {
                            let mid = (lo + hi) / 2
                            if areaLeft(piece.poly, Geo.Line(p: c0 + nrm * mid, d: d)) > want { lo = mid } else { hi = mid }
                        }
                        let line = Geo.Line(p: c0 + nrm * ((lo + hi) / 2), d: d)
                        guard let s = Geo.split(piece.poly, by: line), !blocked(ps, line) else { continue }
                        var crosses = false
                        for (j, o) in ps.enumerated() where j != i { if Geo.split(o.poly, by: line) != nil { crosses = true; break } }
                        if crosses { continue }
                        let g: CGFloat = 8
                        let dl = CGPoint(x: nrm.x * g, y: nrm.y * g - 3), dr = CGPoint(x: -nrm.x * g, y: -nrm.y * g - 3)
                        var lc: [(c: CGPoint, r: CGFloat)] = [], rc: [(c: CGPoint, r: CGFloat)] = []
                        for c in piece.cores { if line.side(c.c) >= 0 { lc.append((c.c + dl, c.r)) } else { rc.append((c.c + dr, c.r)) } }
                        let leftT = sub.map { piece.tg[$0] }
                        let rightT = (0..<piece.tg.count).filter { !sub.contains($0) }.map { piece.tg[$0] }
                        var next = ps
                        next.remove(at: i)
                        next.append(SP(poly: s.left.map { $0 + dl }, cores: lc, tg: leftT))
                        next.append(SP(poly: s.right.map { $0 + dr }, cores: rc, tg: rightT))
                        if dfs(next, cuts - 1) {
                            if cuts == rootCuts { firstLine = line }
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
}
