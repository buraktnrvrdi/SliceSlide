import SpriteKit
import UIKit

struct Core {
    var center: CGPoint
    var radius: CGFloat
}

final class Piece {
    var poly: [CGPoint]
    var cores: [Core]
    var node: SKNode
    init(poly: [CGPoint], cores: [Core], node: SKNode) {
        self.poly = poly; self.cores = cores; self.node = node
    }
    var centroid: CGPoint { Geo.centroid(poly) }
    var area: CGFloat { Geo.area(poly) }
}

final class TargetSlot {
    let node = SKNode()
    let outer: SKShapeNode
    let inner: SKShapeNode
    let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
    let radius: CGFloat
    let fraction: CGFloat

    static let mint = UIColor(196, 255, 222)
    static let coral = UIColor(255, 126, 140)

    init(position: CGPoint, radius: CGFloat, fraction: CGFloat) {
        self.radius = radius
        self.fraction = fraction
        node.position = position

        outer = SKShapeNode(circleOfRadius: radius)
        outer.strokeColor = UIColor(white: 1, alpha: 0.6)
        outer.lineWidth = 3
        outer.fillColor = .clear
        outer.glowWidth = 5

        inner = SKShapeNode(circleOfRadius: radius * 0.72)
        inner.strokeColor = UIColor(white: 1, alpha: 0.4)
        inner.lineWidth = 2
        inner.fillColor = UIColor(white: 1, alpha: 0.10)

        label.text = "%\(Int((fraction * 100).rounded()))"
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -radius - 30)

        node.addChild(outer)
        node.addChild(inner)
        node.addChild(label)

        let pulse = SKAction.sequence([
            .group([.scale(to: 1.045, duration: 1.6), .fadeAlpha(to: 0.75, duration: 1.6)]),
            .group([.scale(to: 1.0, duration: 1.6), .fadeAlpha(to: 1.0, duration: 1.6)]),
        ])
        outer.run(.repeatForever(pulse))
    }

    func show(good: Bool, text: String) {
        outer.removeAllActions()
        outer.setScale(1)
        outer.alpha = 1
        outer.strokeColor = good ? Self.mint : Self.coral
        outer.glowWidth = 10
        inner.strokeColor = (good ? Self.mint : Self.coral).withAlphaComponent(0.55)
        label.text = text
        label.fontColor = good ? Self.mint : Self.coral
        label.fontSize = 16
    }
}

/// Sezona göre kesim efekti: parçacık şekli, renkleri, yer çekimi ve çizgi rengi.
struct CutFX {
    let colors: [UIColor]
    let kind: Int          // 0 daire, 1 buz kıymığı, 2 kum, 3 yaprak, 4 yıldız, 5 kalp, 6 şeker serpmesi
    let gravity: CGFloat
    let line: UIColor

    static func make(_ season: Int) -> CutFX {
        switch season {
        case 1: return CutFX(colors: [UIColor(255, 255, 255), UIColor(190, 235, 255), UIColor(150, 205, 255)], kind: 1, gravity: -20, line: UIColor(225, 247, 255))
        case 2: return CutFX(colors: [UIColor(255, 214, 140), UIColor(255, 174, 96), UIColor(240, 130, 80)], kind: 2, gravity: -70, line: UIColor(255, 238, 200))
        case 3: return CutFX(colors: [UIColor(190, 255, 205), UIColor(120, 220, 150), UIColor(230, 255, 190)], kind: 3, gravity: -26, line: UIColor(225, 255, 225))
        case 4: return CutFX(colors: [UIColor(255, 190, 235), UIColor(190, 160, 255), UIColor(160, 230, 255)], kind: 4, gravity: 0, line: UIColor(250, 220, 255))
        case 5: return CutFX(colors: [UIColor(90, 240, 255), UIColor(255, 100, 225), UIColor(255, 240, 130)], kind: 4, gravity: 0, line: UIColor(205, 248, 255))
        default: return CutFX(colors: [.white], kind: 0, gravity: 0, line: .white)
        }
    }
}

final class GameScene: SKScene {
    weak var session: GameSession?

    private enum State { case idle, playing, resolving, won, lost }
    private var state: State = .idle

    private var pendingLevel: Int?
    private var builtSize: CGSize = .zero
    private var def: LevelDef!
    private var palette = Palette.all[0]
    private var shapeColors: [UIColor] = [.white, .white]
    private var fx = CutFX.make(0)
    private var themeSet: ThemeSet?
    private var drawColor: UIColor = .white
    private var lastTrailDot = CGPoint.zero
    private var baseHalf: CGFloat = 1
    private var motionPoly: [CGPoint] = []
    private var motionCores: [CGPoint] = []
    private var motionCenter: CGPoint = .zero
    private var coreNodes: [SKNode] = []
    private var motionT: CGFloat = 0

    private var pieces: [Piece] = []
    private var slots: [TargetSlot] = []
    private var totalArea: CGFloat = 1
    private var cutsLeft = 0
    private var timeLeft: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var lostAt = Date()

    private let ambient = SKNode()
    private let world = SKNode()
    private let overlay = SKNode()
    private let guideLine = SKShapeNode()
    private let cutLine = SKShapeNode()
    private var labelPool: [SKLabelNode] = []
    private var timerBar: SKSpriteNode?

    private var dragStart: CGPoint?
    private var usedHint = false
    private var buildGen = 0
    private var lastTick = CGPoint.zero
    private var hintActive = false
    private let hintLine = SKNode()
    private var dragTouch: UITouch?

    // MARK: - Yükleme

    func load(level: Int) {
        pendingLevel = level
        builtSize = .zero
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        if size != builtSize { build() }
    }

    private func publish(_ block: @escaping (GameSession) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let s = self?.session { block(s) }
        }
    }

    private func build() {
        guard let level = pendingLevel, size.width > 20, size.height > 20 else { return }
        builtSize = size
        removeAllActions()
        for n in [ambient, world, overlay] {
            n.removeAllChildren()
            n.removeAllActions()
            if n.parent == nil { addChild(n) }
        }
        ambient.zPosition = 0
        world.zPosition = 1
        overlay.zPosition = 10

        def = LevelFactory.make(level)
        palette = Palette.forLevel(level)
        let prog0 = PlayerProgress.shared
        let seasonIndex = session?.mode == .flow ? 5 : Season.of(level: level).index
        themeSet = ThemeSet.active
        fx = themeSet?.fx ?? CutFX.make(seasonIndex)
        if prog0.selectedTrail != 0, prog0.trailUnlocked(prog0.selectedTrail), let tr = Trail.all.first(where: { $0.id == prog0.selectedTrail }) {
            fx = CutFX(colors: tr.colors, kind: tr.kind, gravity: tr.gravity, line: tr.line)
        }
        SFX.shared.season = themeSet?.sfx ?? seasonIndex
        drawColor = themeSet?.drawLine ?? .white
        shapeColors = themeSet?.shapeColors ?? [palette.shapeTop, palette.shapeBottom]
        let prog = PlayerProgress.shared
        if prog.selectedSkin >= 0, prog.skinUnlocked(prog.selectedSkin) {
            shapeColors = Skin.all[prog.selectedSkin].colors
        }
        state = .playing
        cutsLeft = def.cuts
        timeLeft = def.timeLimit ?? 0
        lastTime = 0
        pieces = []
        slots = []
        dragStart = nil
        dragTouch = nil
        timerBar = nil
        usedHint = false
        hintActive = false
        speed = 1
        buildGen += 1
        hintLine.removeAllActions()

        let w = size.width, h = size.height
        buildAmbient(w, h)

        // Hedef halkalar
        let n = def.targets.count
        let spacing = w / CGFloat(n)
        let baseR = min(spacing * 0.36, 62)
        for (i, f) in def.targets.enumerated() {
            let r = baseR * (0.62 + 0.76 * f)
            let pos = CGPoint(x: spacing * (CGFloat(i) + 0.5), y: h * 0.235)
            let slot = TargetSlot(position: pos, radius: r, fraction: f)
            slot.node.zPosition = 1
            slot.node.alpha = 0
            slot.node.run(.fadeIn(withDuration: 0.4))
            world.addChild(slot.node)
            slots.append(slot)
        }

        // Şekil
        let half = min(w * 0.30, h * 0.17)
        baseHalf = half
        let center = CGPoint(x: w / 2, y: h * 0.6)
        let poly = def.shape.map { center + $0 * half }
        let cores = def.obstacles.map { Core(center: center + $0.center * half, radius: $0.radius * half) }
        totalArea = Geo.area(poly)
        let node = makeNode(poly: poly, cores: cores)
        node.alpha = 0
        node.setScale(0.82)
        node.run(.group([.fadeIn(withDuration: 0.35), Self.ease(.scale(to: 1, duration: 0.35), .easeOut)]))
        world.addChild(node)
        pieces = [Piece(poly: poly, cores: cores, node: node)]
        motionCenter = Geo.centroid(poly)
        motionPoly = poly.map { $0 - motionCenter }
        motionCores = cores.map { $0.center - motionCenter }
        coreNodes = node.children
        motionT = 0

        // Kesim çizgisi katmanları
        guideLine.lineWidth = 2
        guideLine.isHidden = true
        cutLine.lineWidth = 4.5
        cutLine.lineCap = .round
        cutLine.glowWidth = themeSet == nil ? 4 : 9
        cutLine.isHidden = true
        hintLine.isHidden = true
        hintLine.zPosition = 7
        overlay.addChild(hintLine)
        overlay.addChild(guideLine)
        overlay.addChild(cutLine)
        labelPool = (0..<12).map { _ in
            let l = SKLabelNode(fontNamed: "AvenirNext-Medium")
            l.fontSize = 20
            l.fontColor = .white
            l.verticalAlignmentMode = .center
            l.isHidden = true
            l.zPosition = 5
            overlay.addChild(l)
            return l
        }

        // Süre çubuğu (zamanlı bölümler)
        if def.timeLimit != nil {
            let barW = w * 0.5
            let back = SKSpriteNode(color: UIColor(white: 1, alpha: 0.25), size: CGSize(width: barW, height: 4))
            back.position = CGPoint(x: w / 2, y: h - 172)
            overlay.addChild(back)
            let bar = SKSpriteNode(color: .white, size: CGSize(width: barW, height: 4))
            bar.anchorPoint = CGPoint(x: 0, y: 0.5)
            bar.position = CGPoint(x: w / 2 - barW / 2, y: h - 172)
            bar.zPosition = 1
            overlay.addChild(bar)
            timerBar = bar
        }

        let total = def.cuts
        publish { s in
            s.totalCuts = total
            s.cutsLeft = total
        }
        #if DEBUG
        if Self.demo { scheduleDemo(after: 1.1) }
        #endif
    }

    #if DEBUG
    // MARK: - Demo (yalnızca test derlemesi, `-demo` argümanı): tanıtım videosu için kendi kendine oynar

    static let demo = ProcessInfo.processInfo.arguments.contains("-demo")
    private let demoFinger = SKShapeNode(circleOfRadius: 17)

    private func scheduleDemo(after delay: TimeInterval) {
        let gen = buildGen
        run(.sequence([.wait(forDuration: delay), .run { [weak self] in
            guard let self, gen == self.buildGen else { return }
            self.demoStep()
        }]), withKey: "demo")
    }

    private func demoStep() {
        guard state == .playing, cutsLeft > 0 else { return }
        hintActive = true   // çözüm aranırken ve çizilirken şekil donsun
        let snapshot = pieces.map { (poly: $0.poly, cores: $0.cores.map { (c: $0.center, r: $0.radius) }) }
        let solver = HintSolver(targets: def.targets, tol: def.tolerance * 0.5, total: totalArea)
        let left = cutsLeft, gen = buildGen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let line = solver.solve(pieces: snapshot, cutsLeft: left)
                ?? HintSolver(targets: self?.def.targets ?? [], tol: self?.def.tolerance ?? 0.05, total: self?.totalArea ?? 1)
                    .solve(pieces: snapshot, cutsLeft: left)
            DispatchQueue.main.async {
                guard let self, gen == self.buildGen, self.state == .playing else { return }
                guard let line else { self.hintActive = false; return }
                self.demoDrag(line)
            }
        }
    }

    private func demoDrag(_ line: Geo.Line) {
        // Parçaları kapsayan bölüm + biraz pay
        let all = pieces.flatMap { $0.poly }
        let ts = all.map { ($0 - line.p).x * line.d.x + ($0 - line.p).y * line.d.y }
        let a = line.p + line.d * ((ts.min() ?? -100) - 46)
        let b = line.p + line.d * ((ts.max() ?? 100) + 46)
        if demoFinger.parent == nil {
            demoFinger.fillColor = UIColor(white: 1, alpha: 0.35)
            demoFinger.strokeColor = UIColor(white: 1, alpha: 0.9)
            demoFinger.lineWidth = 2
            demoFinger.glowWidth = 6
            demoFinger.zPosition = 20
            overlay.addChild(demoFinger)
        }
        demoFinger.removeAllActions()
        demoFinger.position = a
        demoFinger.setScale(0.6)
        demoFinger.alpha = 0
        lastTrailDot = a
        let dur = 0.42
        let drag = SKAction.customAction(withDuration: dur) { [weak self] _, t in
            guard let self else { return }
            let k = CGFloat(t) / CGFloat(dur)
            let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2   // easeInOut
            let p = a + (b - a) * e
            self.demoFinger.position = p
            self.updatePreview(from: a, to: p)
            if (p - self.lastTrailDot).length >= 14 { self.trailDot(at: p); self.lastTrailDot = p }
        }
        demoFinger.run(.sequence([
            .group([.fadeIn(withDuration: 0.12), .scale(to: 1, duration: 0.12)]),
            .wait(forDuration: 0.08),
            drag,
            .run { [weak self] in
                guard let self else { return }
                self.endDrag()
                self.hintActive = false
                self.performCut(from: a, to: b)
                if self.cutsLeft > 0 { self.scheduleDemo(after: 0.75) }
            },
            .group([.fadeOut(withDuration: 0.2), .scale(to: 0.6, duration: 0.2)]),
        ]))
    }
    #endif

    private func buildAmbient(_ w: CGFloat, _ h: CGFloat) {
        if themeSet?.decor == .candy { buildCandyAmbient(w, h) }
        for _ in 0..<16 {
            let s = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...3))
            s.fillColor = themeSet == nil ? .white : [UIColor.white, UIColor(255, 214, 236)].randomElement()!
            s.strokeColor = .clear
            s.glowWidth = 3
            s.alpha = CGFloat.random(in: 0.15...0.55)
            s.position = CGPoint(x: .random(in: 0...w), y: .random(in: h * 0.1...h * 0.9))
            let dx = CGFloat.random(in: -14...14), dy = CGFloat.random(in: -18...18)
            let dur = Double.random(in: 3...6)
            s.run(.repeatForever(.sequence([
                .group([.moveBy(x: dx, y: dy, duration: dur), .fadeAlpha(to: 0.1, duration: dur)]),
                .group([.moveBy(x: -dx, y: -dy, duration: dur), .fadeAlpha(to: 0.6, duration: dur)]),
            ])))
            ambient.addChild(s)
        }
    }

    /// Pamuk Şeker: yavaşça yükselen minik kalpler ve şeker taneleri.
    private func buildCandyAmbient(_ w: CGFloat, _ h: CGFloat) {
        let spawn = SKAction.run { [weak self] in
            guard let self else { return }
            let heart = Int.random(in: 0..<3) > 0
            let n = self.sparkNode(kind: heart ? 5 : 6, size: .random(in: 1.6...3.2),
                                   color: [UIColor.white, UIColor(255, 190, 222), UIColor(255, 150, 200)].randomElement()!)
            n.position = CGPoint(x: .random(in: 0...w), y: -20)
            n.alpha = .random(in: 0.35...0.7)
            n.zRotation = .random(in: -0.4...0.4)
            self.ambient.addChild(n)
            let dur = Double.random(in: 9...14)
            let sway = SKAction.repeatForever(.sequence([
                Self.ease(.moveBy(x: 18, y: 0, duration: 1.8), .easeInEaseOut),
                Self.ease(.moveBy(x: -18, y: 0, duration: 1.8), .easeInEaseOut),
            ]))
            n.run(sway)
            n.run(.sequence([.moveBy(x: 0, y: h + 60, duration: dur), .removeFromParent()]))
        }
        ambient.run(.repeatForever(.sequence([spawn, .wait(forDuration: 0.9, withRange: 0.6)])))
    }

    /// Sürüklerken imlecin arkasında kalan pembe parıltı ve kalpler.
    private func trailDot(at p: CGPoint) {
        guard themeSet != nil else { return }
        let glow = SKShapeNode(circleOfRadius: 5)
        glow.fillColor = UIColor(255, 200, 230)
        glow.strokeColor = .clear
        glow.glowWidth = 7
        glow.position = p
        glow.zPosition = 8
        overlay.addChild(glow)
        glow.run(.sequence([.group([.scale(to: 0.2, duration: 0.45), .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
        if Int.random(in: 0..<3) == 0 {
            let h = sparkNode(kind: 5, size: .random(in: 1.8...2.8), color: fx.colors.randomElement()!)
            h.position = p
            h.zPosition = 9
            overlay.addChild(h)
            h.run(.sequence([.group([.moveBy(x: .random(in: -14...14), y: .random(in: 16...34), duration: 0.8),
                                     .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        }
    }

    private static func gradientTexture(top: UIColor, bottom: UIColor) -> SKTexture {
        let size = CGSize(width: 64, height: 64)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: img)
    }

    private static func ease(_ a: SKAction, _ m: SKActionTimingMode) -> SKAction {
        a.timingMode = m
        return a
    }

    // MARK: - Parça düğümleri

    private func makeNode(poly: [CGPoint], cores: [Core]) -> SKNode {
        let c = Geo.centroid(poly)
        let (tex, size, anchor) = Glass.piece(poly: poly, colors: shapeColors, sprinkles: themeSet?.decor == .candy)
        let node = SKSpriteNode(texture: tex, size: size)
        node.anchorPoint = anchor
        node.position = c
        for core in cores { node.addChild(makeCoreNode(core, relativeTo: c)) }
        return node
    }

    private func makeCoreNode(_ core: Core, relativeTo c: CGPoint) -> SKNode {
        let (tex, size) = Glass.core(radius: core.radius, candy: themeSet?.decor == .candy)
        let n = SKSpriteNode(texture: tex, size: size)
        n.position = core.center - c
        n.zPosition = 2
        return n
    }

    private func spawn(poly: [CGPoint], cores: [Core], from offset: CGVector) -> Piece {
        let node = makeNode(poly: poly, cores: cores)
        let final = node.position
        node.position = CGPoint(x: final.x - offset.dx, y: final.y - offset.dy)
        node.run(Self.ease(.move(to: final, duration: 0.3), .easeOut))
        let pct = SKLabelNode(fontNamed: "AvenirNext-Medium")
        pct.text = "%\(Int((Geo.area(poly) / totalArea * 100).rounded()))"
        pct.fontSize = 22
        pct.fontColor = .white
        pct.verticalAlignmentMode = .center
        pct.zPosition = 4
        pct.alpha = 0
        pct.run(.sequence([.wait(forDuration: 0.15), .fadeIn(withDuration: 0.2)]))
        node.addChild(pct)
        world.addChild(node)
        return Piece(poly: poly, cores: cores, node: node)
    }

    // MARK: - Dokunuşlar

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if session?.phase == .paused { return }
        if state == .lost {
            if Date().timeIntervalSince(lostAt) > 0.35 { session?.restart() }
            return
        }
        guard state == .playing, dragTouch == nil else { return }
        dragTouch = t
        dragStart = t.location(in: self)
        lastTick = dragStart ?? .zero
        lastTrailDot = lastTick
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t), let a = dragStart else { return }
        let loc = t.location(in: self)
        if (loc - lastTick).length >= 26 { Haptics.tick(); lastTick = loc }
        if (loc - lastTrailDot).length >= 14 { trailDot(at: loc); lastTrailDot = loc }
        updatePreview(from: a, to: loc)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t), let a = dragStart else { return }
        let b = t.location(in: self)
        endDrag()
        if (b - a).length >= 40, state == .playing { performCut(from: a, to: b) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag()
    }

    private func endDrag() {
        dragTouch = nil
        dragStart = nil
        guideLine.isHidden = true
        cutLine.isHidden = true
        labelPool.forEach { $0.isHidden = true }
    }

    // MARK: - Önizleme

    private func isBlocked(_ line: Geo.Line) -> Bool {
        for piece in pieces {
            for core in piece.cores where abs(line.side(core.center)) < core.radius + 3 { return true }
        }
        return false
    }

    private func updatePreview(from a: CGPoint, to b: CGPoint) {
        let v = b - a
        guard v.length > 1 else { return }
        let d = v.unit
        let line = Geo.Line(p: a, d: d)
        let blocked = isBlocked(line)

        let gp = CGMutablePath()
        gp.move(to: a - d * 2500)
        gp.addLine(to: a + d * 2500)
        guideLine.path = gp
        guideLine.strokeColor = blocked ? TargetSlot.coral.withAlphaComponent(0.45) : UIColor(white: 1, alpha: 0.2)
        guideLine.isHidden = false

        let sp = CGMutablePath()
        sp.move(to: a)
        sp.addLine(to: b)
        cutLine.path = sp
        cutLine.strokeColor = blocked ? TargetSlot.coral : drawColor
        cutLine.isHidden = false

        labelPool.forEach { $0.isHidden = true }
        guard def.showsPreview, !blocked, v.length > 30 else { return }
        var idx = 0
        func put(_ poly: [CGPoint]) {
            guard idx < labelPool.count else { return }
            let l = labelPool[idx]
            idx += 1
            l.text = "%\(Int((Geo.area(poly) / totalArea * 100).rounded()))"
            l.position = Geo.centroid(poly)
            l.isHidden = false
        }
        for piece in pieces {
            if let s = Geo.split(piece.poly, by: line) {
                put(s.left)
                put(s.right)
            }
        }
    }

    // MARK: - Kesme

    private func performCut(from a: CGPoint, to b: CGPoint) {
        let line = Geo.Line(p: a, d: (b - a).unit)
        if isBlocked(line) {
            deny()
            return
        }

        var next: [Piece] = []
        var segments: [(CGPoint, CGPoint)] = []
        let n = line.leftNormal
        let gap: CGFloat = 8
        let dl = CGVector(dx: n.x * gap, dy: n.y * gap - 3)
        let dr = CGVector(dx: -n.x * gap, dy: -n.y * gap - 3)

        for piece in pieces {
            guard let s = Geo.split(piece.poly, by: line) else {
                next.append(piece)
                continue
            }
            segments.append((s.cutA, s.cutB))
            piece.node.removeFromParent()
            var lc: [Core] = [], rc: [Core] = []
            for c in piece.cores {
                if line.side(c.center) >= 0 {
                    lc.append(Core(center: CGPoint(x: c.center.x + dl.dx, y: c.center.y + dl.dy), radius: c.radius))
                } else {
                    rc.append(Core(center: CGPoint(x: c.center.x + dr.dx, y: c.center.y + dr.dy), radius: c.radius))
                }
            }
            let lp = s.left.map { CGPoint(x: $0.x + dl.dx, y: $0.y + dl.dy) }
            let rp = s.right.map { CGPoint(x: $0.x + dr.dx, y: $0.y + dr.dy) }
            next.append(spawn(poly: lp, cores: lc, from: dl))
            next.append(spawn(poly: rp, cores: rc, from: dr))
        }

        guard !segments.isEmpty else { return }   // çizgi şekle değmedi: hak harcanmaz
        pieces = next
        cutsLeft -= 1
        PlayerProgress.shared.addCut()
        clearHint()

        flash(line: line)
        for (p, q) in segments {
            for i in 0..<5 { sparkle(at: p + (q - p) * (CGFloat(i) / 4), count: 3, spread: 36) }
        }
        SFX.shared.play(.cut, semitones: Double(min(session?.combo ?? 0, 7)))
        Haptics.cut(soft: themeSet != nil)
        hitStop()
        let left = cutsLeft
        publish { $0.cutsLeft = left }

        if cutsLeft == 0 {
            state = .resolving
            run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.resolve() }]), withKey: "resolve")
        }
    }

    /// Kesim anında kısa slow-motion ve hafif kamera vuruşu.
    private func hitStop() {
        speed = 0.25
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let punch: CGFloat = 1.03
        world.run(.sequence([
            .group([Self.ease(.scale(to: punch, duration: 0.06), .easeOut),
                    Self.ease(.move(to: CGPoint(x: c.x * (1 - punch), y: c.y * (1 - punch)), duration: 0.06), .easeOut)]),
            .group([Self.ease(.scale(to: 1, duration: 0.18), .easeInEaseOut),
                    Self.ease(.move(to: .zero, duration: 0.18), .easeInEaseOut)]),
        ]), withKey: "punch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.speed = 1 }
    }

    private func flash(line: Geo.Line) {
        let path = CGMutablePath()
        path.move(to: line.p - line.d * 2500)
        path.addLine(to: line.p + line.d * 2500)
        let f = SKShapeNode(path: path)
        f.strokeColor = fx.line
        f.lineWidth = 5
        f.glowWidth = 6
        f.zPosition = 8
        overlay.addChild(f)
        f.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func sparkNode(kind: Int, size: CGFloat, color: UIColor) -> SKShapeNode {
        let n: SKShapeNode
        switch kind {
        case 1: // buz kıymığı: ince eşkenar dörtgen
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: size * 2.2)); p.addLine(to: CGPoint(x: size * 0.8, y: 0))
            p.addLine(to: CGPoint(x: 0, y: -size * 1.2)); p.addLine(to: CGPoint(x: -size * 0.8, y: 0)); p.closeSubpath()
            n = SKShapeNode(path: p)
        case 3: // yaprak
            n = SKShapeNode(ellipseOf: CGSize(width: size * 2.6, height: size * 1.3))
        case 4: // dört köşeli yıldız
            let p = CGMutablePath()
            let r = size * 2.4, ri = size * 0.6
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4 - .pi / 2
                let rr = i % 2 == 0 ? r : ri
                let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            n = SKShapeNode(path: p)
        case 5: // kalp
            let r = size * 1.3
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: -r * 1.1))
            p.addCurve(to: CGPoint(x: 0, y: r * 0.55), control1: CGPoint(x: r * 1.9, y: -r * 0.1), control2: CGPoint(x: r * 0.9, y: r * 1.5))
            p.addCurve(to: CGPoint(x: 0, y: -r * 1.1), control1: CGPoint(x: -r * 0.9, y: r * 1.5), control2: CGPoint(x: -r * 1.9, y: -r * 0.1))
            p.closeSubpath()
            n = SKShapeNode(path: p)
        case 6: // şeker serpmesi
            n = SKShapeNode(rect: CGRect(x: -size * 1.6, y: -size * 0.5, width: size * 3.2, height: size), cornerRadius: size * 0.5)
        default:
            n = SKShapeNode(circleOfRadius: size)
        }
        n.fillColor = color
        n.strokeColor = .clear
        n.glowWidth = (kind == 2 || kind == 6) ? 0 : 2
        return n
    }

    private func sparkle(at p: CGPoint, color: UIColor? = nil, count: Int = 8, spread: CGFloat = 40) {
        for _ in 0..<count {
            let c = color ?? fx.colors.randomElement()!
            var kind = color == nil ? fx.kind : (fx.kind == 0 ? 0 : fx.kind)
            if kind == 5, Int.random(in: 0..<3) == 0 { kind = 6 }   // kalplerin arasına şeker taneleri
            let s = sparkNode(kind: kind, size: .random(in: 1.4...3.4), color: c)
            s.position = p
            s.zPosition = 9
            s.zRotation = .random(in: 0..<(2 * .pi))
            overlay.addChild(s)
            let ang = CGFloat.random(in: 0..<(2 * .pi))
            let dist = CGFloat.random(in: spread * 0.4...spread)
            let dur = fx.kind == 2 ? 0.8 : 0.55
            var spin: SKAction = .wait(forDuration: 0)
            if fx.kind == 3 || fx.kind == 1 || fx.kind >= 4 { spin = .rotate(byAngle: .random(in: -3...3), duration: dur) }
            s.run(.sequence([
                .group([Self.ease(.moveBy(x: cos(ang) * dist, y: sin(ang) * dist + fx.gravity, duration: dur), .easeOut),
                        .fadeOut(withDuration: dur), spin]),
                .removeFromParent(),
            ]))
        }
    }

    private func deny() {
        SFX.shared.play(.deny)
        Haptics.warning()
        for piece in pieces {
            piece.node.run(.sequence([.moveBy(x: 7, y: 0, duration: 0.04), .moveBy(x: -14, y: 0, duration: 0.07),
                                      .moveBy(x: 14, y: 0, duration: 0.07), .moveBy(x: -7, y: 0, duration: 0.04)]))
        }
    }

    // MARK: - İpucu

    private func clearHint() {
        hintActive = false
        hintLine.removeAllActions()
        hintLine.removeAllChildren()
        hintLine.isHidden = true
    }

    /// Kesim için çözüm arar; bulunursa çizgiyi gösterir (şekil ve süre 7 sn donar).
    func requestHint(_ completion: @escaping (Bool) -> Void) {
        guard state == .playing, def != nil, !hintActive else { completion(false); return }
        hintActive = true   // aramadan önce dondur: durum değişmesin
        let snapshot = pieces.map { (poly: $0.poly, cores: $0.cores.map { (c: $0.center, r: $0.radius) }) }
        let solver = HintSolver(targets: def.targets, tol: def.tolerance, total: totalArea)
        let left = cutsLeft
        let gen = buildGen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let line = solver.solve(pieces: snapshot, cutsLeft: left)
            DispatchQueue.main.async {
                guard let self else { return }
                guard gen == self.buildGen else { completion(false); return }
                guard let line, self.state == .playing else {
                    self.hintActive = false
                    completion(false)
                    return
                }
                self.usedHint = true
                self.showHint(line)
                completion(true)
            }
        }
    }

    private func showHint(_ line: Geo.Line) {
        hintLine.removeAllActions()
        hintLine.removeAllChildren()
        let length = size.width * 1.3
        let (tex, texSize) = Glass.hintLine(length: length)
        let body = SKSpriteNode(texture: tex, size: texSize)
        hintLine.addChild(body)
        let (dotTex, dotSize) = Glass.glowDot(radius: 20)
        let dot = SKSpriteNode(texture: dotTex, size: dotSize)
        dot.zPosition = 1
        dot.position = CGPoint(x: -length * 0.4, y: 0)
        hintLine.addChild(dot)
        dot.run(.repeatForever(.sequence([
            Self.ease(.moveTo(x: length * 0.4, duration: 1.6), .easeInEaseOut),
            .moveTo(x: -length * 0.4, duration: 0),
        ])))
        hintLine.position = line.p
        hintLine.zRotation = atan2(line.d.y, line.d.x)
        hintLine.alpha = 0
        hintLine.isHidden = false
        hintLine.run(.sequence([
            .fadeIn(withDuration: 0.25),
            .repeatForever(.sequence([.fadeAlpha(to: 0.78, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)])),
        ]))
        run(.sequence([.wait(forDuration: 7), .run { [weak self] in self?.clearHint() }]), withKey: "hintTimeout")
    }

    // MARK: - Değerlendirme

    private func resolve() {
        state = .resolving
        let sorted = pieces.sorted { $0.centroid.x < $1.centroid.x }

        guard sorted.count == slots.count else {
            for (i, p) in sorted.enumerated() {
                p.node.run(.sequence([.wait(forDuration: 0.06 * Double(i)),
                                      .group([Self.ease(.moveBy(x: 0, y: -size.height * 0.5, duration: 0.6), .easeIn),
                                              .fadeOut(withDuration: 0.6)])]))
            }
            let msg = "\(sorted.count) parça çıktı, \(slots.count) hedef var"
            run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in self?.fail(message: msg, near: false) }]))
            return
        }

        // Her parça, alanına en uygun halkaya gider (yatay/dikey kesim fark etmez).
        let match = Geo.bestMatch(sorted.map { $0.area / totalArea }, slots.map { $0.fraction })
        var ordered = sorted
        for (pi, si) in match.enumerated() { ordered[si] = sorted[pi] }
        var maxErr: CGFloat = 0
        var results: [(good: Bool, text: String)] = []
        for (i, piece) in ordered.enumerated() {
            let slot = slots[i]
            let actual = piece.area / totalArea
            let err = abs(actual - slot.fraction)
            maxErr = max(maxErr, err)
            let good = err <= def.tolerance
            let a = Int((actual * 100).rounded()), t = Int((slot.fraction * 100).rounded())
            results.append((good, good ? "%\(a)" : "%\(a) → %\(t)"))

            let node = piece.node
            let xs = piece.poly.map { $0.x }, ys = piece.poly.map { $0.y }
            let bw = (xs.max() ?? 0) - (xs.min() ?? 0), bh = (ys.max() ?? 0) - (ys.min() ?? 0)
            let scale = min(1, (slot.radius * 1.5) / max(bw, bh, 1))
            node.zPosition = 5 + CGFloat(i)
            let move = Self.ease(.move(to: slot.node.position, duration: 0.6), .easeIn)
            let shrink = Self.ease(.scale(to: scale, duration: 0.6), .easeInEaseOut)
            let rot = SKAction.rotate(toAngle: .random(in: -0.12...0.12), duration: 0.6, shortestUnitArc: true)
            let bounce = SKAction.sequence([Self.ease(.moveBy(x: 0, y: 9, duration: 0.1), .easeOut),
                                            Self.ease(.moveBy(x: 0, y: -9, duration: 0.13), .easeIn)])
            let slotRef = slot
            let comboNote = min(session?.combo ?? 0, 4)
            node.run(.sequence([.wait(forDuration: 0.09 * Double(i)), .group([move, shrink, rot]), bounce,
                                .run { [weak self] in self?.landFX(slotRef, index: i, good: good, comboBoost: comboNote) }]))
        }

        let tol = def.tolerance
        let ok = maxErr <= tol
        let wait = 0.09 * Double(ordered.count) + 0.95
        run(.sequence([.wait(forDuration: wait), .run { [weak self] in
            guard let self else { return }
            for (i, r) in results.enumerated() {
                self.slots[i].show(good: r.good, text: r.text)
                self.sparkle(at: self.slots[i].node.position, color: r.good ? TargetSlot.mint : TargetSlot.coral,
                             count: 10, spread: self.slots[i].radius * 1.3)
            }
            if ok {
                let stars = maxErr <= tol * 0.4 ? 3 : (maxErr <= tol * 0.7 ? 2 : 1)
                self.win(stars: stars, perfect: maxErr <= 0.01)
            } else {
                let pct = Int((maxErr * 100).rounded())
                let near = maxErr <= tol * 2.2
                self.fail(message: near ? "Çok yakın! En büyük sapma %\(pct)" : "Olmadı. En büyük sapma %\(pct)", near: near)
            }
        }]), withKey: "resolve")
    }

    /// Parça halkaya oturunca dalga, kıvılcım, nota ve titreşim.
    private func landFX(_ slot: TargetSlot, index: Int, good: Bool, comboBoost: Int) {
        let ring = SKShapeNode(circleOfRadius: slot.radius)
        ring.position = slot.node.position
        ring.strokeColor = good ? TargetSlot.mint : TargetSlot.coral
        ring.lineWidth = 4
        ring.glowWidth = 6
        ring.fillColor = .clear
        ring.zPosition = 8
        overlay.addChild(ring)
        ring.run(.sequence([.group([Self.ease(.scale(to: 1.55, duration: 0.5), .easeOut), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        if good {
            sparkle(at: slot.node.position, color: TargetSlot.mint, count: 7, spread: slot.radius * 1.1)
            SFX.shared.playNote(index * 2 + comboBoost)
        }
        Haptics.land()
    }

    /// Sezona özel kutlama: kristal parıltısı, kar, kum, yapraklar, yıldız yağmuru.
    private func celebrate(big: Bool) {
        let w = size.width, h = size.height
        let season = session?.mode == .flow ? 5 : Season.of(level: def.number).index
        let n = big ? 80 : 34
        func drop(_ node: SKNode, fromTop: Bool, sway: CGFloat, dur: Double, delay: Double, spin: CGFloat) {
            node.position = CGPoint(x: .random(in: 0...w), y: fromTop ? h + 24 : -24)
            node.zPosition = 6
            node.alpha = 0
            overlay.addChild(node)
            let dy = (fromTop ? -1 : 1) * (h + 60)
            node.run(.sequence([
                .wait(forDuration: delay),
                .fadeAlpha(to: 1, duration: 0.01),
                .group([
                    Self.ease(.moveBy(x: sway, y: dy, duration: dur), fromTop ? .easeIn : .easeOut),
                    .rotate(byAngle: spin, duration: dur),
                    .sequence([.wait(forDuration: dur * 0.65), .fadeOut(withDuration: dur * 0.35)]),
                ]),
                .removeFromParent(),
            ]))
        }
        if themeSet?.decor == .candy {
            // Pamuk Şeker: yağan kalpler ve şeker serpmesi, yükselen pembe pofuduklar
            for i in 0..<n {
                let node = sparkNode(kind: i % 3 == 0 ? 6 : 5, size: .random(in: 2.0...4.4), color: fx.colors.randomElement()!)
                drop(node, fromTop: true, sway: .random(in: -70...70), dur: .random(in: 1.9...3.0), delay: .random(in: 0...0.8), spin: .random(in: -3...3))
            }
            for _ in 0..<(big ? 18 : 9) {
                let puff = SKShapeNode(circleOfRadius: .random(in: 8...16))
                puff.fillColor = [UIColor.white, UIColor(255, 210, 234)].randomElement()!.withAlphaComponent(0.7)
                puff.strokeColor = .clear
                puff.glowWidth = 10
                drop(puff, fromTop: false, sway: .random(in: -40...40), dur: .random(in: 2.2...3.2), delay: .random(in: 0...0.9), spin: 0)
            }
            return
        }
        switch season {
        case 1: // Buz: kar yağışı + kıymıklar
            for i in 0..<n {
                let c = fx.colors.randomElement()!
                let node = sparkNode(kind: i % 4 == 0 ? 1 : 0, size: .random(in: 1.8...4.8), color: c)
                drop(node, fromTop: true, sway: .random(in: -50...50), dur: .random(in: 1.7...2.8), delay: .random(in: 0...0.7), spin: .random(in: -3...3))
            }
        case 2: // Çöl: yükselen altın kum
            for _ in 0..<n {
                let node = sparkNode(kind: 2, size: .random(in: 1.4...3.4), color: fx.colors.randomElement()!)
                drop(node, fromTop: false, sway: .random(in: -80...80), dur: .random(in: 1.5...2.5), delay: .random(in: 0...0.7), spin: 0)
            }
        case 3: // Orman: dönerek düşen yapraklar
            for _ in 0..<n {
                let node = sparkNode(kind: 3, size: .random(in: 2.4...4.4), color: fx.colors.randomElement()!)
                drop(node, fromTop: true, sway: .random(in: -90...90), dur: .random(in: 2.0...3.2), delay: .random(in: 0...0.8), spin: .random(in: -6...6))
            }
        case 4, 5: // Nova / Akış: yıldız yağmuru ve kayan yıldızlar
            for _ in 0..<n {
                let node = sparkNode(kind: 4, size: .random(in: 1.2...3.2), color: fx.colors.randomElement()!)
                node.position = CGPoint(x: .random(in: 0...w), y: .random(in: h * 0.15...h * 0.95))
                node.zPosition = 6
                node.setScale(0.1)
                node.alpha = 0
                overlay.addChild(node)
                node.run(.sequence([
                    .wait(forDuration: .random(in: 0...1.0)),
                    .group([.fadeIn(withDuration: 0.2), Self.ease(.scale(to: 1.4, duration: 0.35), .easeOut)]),
                    .group([.fadeOut(withDuration: 0.5), .scale(to: 0.2, duration: 0.5)]),
                    .removeFromParent(),
                ]))
            }
            for k in 0..<(big ? 5 : 3) {
                let streak = SKShapeNode(rect: CGRect(x: 0, y: -1.5, width: 70, height: 3), cornerRadius: 1.5)
                streak.fillColor = fx.colors.randomElement()!
                streak.strokeColor = .clear
                streak.glowWidth = 4
                streak.zPosition = 7
                streak.position = CGPoint(x: .random(in: 0...w) + 80, y: h * .random(in: 0.7...1.0))
                streak.zRotation = .pi * 1.18
                streak.alpha = 0
                overlay.addChild(streak)
                streak.run(.sequence([
                    .wait(forDuration: 0.15 + 0.3 * Double(k)),
                    .fadeIn(withDuration: 0.05),
                    .group([.moveBy(x: -w * 0.7, y: -h * 0.45, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]),
                    .removeFromParent(),
                ]))
            }
        default: // Kristal Vadisi: yükselen pastel parıltılar
            for i in 0..<n {
                let node = sparkNode(kind: i % 3 == 0 ? 4 : 0, size: .random(in: 1.6...3.8), color: [UIColor.white, TargetSlot.mint, UIColor(255, 214, 240)].randomElement()!)
                drop(node, fromTop: false, sway: .random(in: -40...40), dur: .random(in: 1.6...2.6), delay: .random(in: 0...0.8), spin: .random(in: -2...2))
            }
        }
    }

    /// Kusursuz kesim: altın şok dalgaları ve yazı.
    private func perfectBurst() {
        for slot in slots {
            for k in 0..<2 {
                let ring = SKShapeNode(circleOfRadius: slot.radius * 0.8)
                ring.position = slot.node.position
                ring.strokeColor = UIColor(255, 224, 120)
                ring.lineWidth = 5
                ring.glowWidth = 10
                ring.fillColor = .clear
                ring.zPosition = 9
                ring.alpha = 0
                overlay.addChild(ring)
                ring.run(.sequence([.wait(forDuration: 0.12 * Double(k)), .fadeIn(withDuration: 0.01),
                                    .group([Self.ease(.scale(to: 2.2, duration: 0.7), .easeOut), .fadeOut(withDuration: 0.7)]),
                                    .removeFromParent()]))
            }
            sparkle(at: slot.node.position, color: UIColor(255, 226, 130), count: 16, spread: slot.radius * 1.9)
        }
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = "KUSURSUZ"
        label.fontSize = 40
        label.fontColor = UIColor(255, 232, 150)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        label.zPosition = 12
        label.setScale(0.4)
        label.alpha = 0
        overlay.addChild(label)
        label.run(.sequence([
            .group([Self.ease(.scale(to: 1.15, duration: 0.25), .easeOut), .fadeIn(withDuration: 0.15)]),
            .scale(to: 1, duration: 0.12),
            .wait(forDuration: 0.9),
            .group([.fadeOut(withDuration: 0.4), .moveBy(x: 0, y: 20, duration: 0.4)]),
            .removeFromParent(),
        ]))
    }

    private func win(stars rawStars: Int, perfect: Bool) {
        state = .won
        if perfect { SFX.shared.play(.perfect); Haptics.perfect(); perfectBurst() } else { SFX.shared.play(.win); Haptics.success() }
        let stars = usedHint ? min(rawStars, 2) : rawStars   // ipucu kullanıldıysa en fazla 2 yıldız
        let level = def.number
        let daily = session?.daily ?? false
        let flow = session?.mode == .flow
        var reward: (reward: Int, streak: Int, shield: Bool)?
        if flow {
            // Akış modunda bölüm ilerlemesi yazılmaz
        } else if daily {
            reward = PlayerProgress.shared.completeDaily(perfect: perfect)
        } else {
            PlayerProgress.shared.complete(level: level, stars: stars, perfect: perfect)
        }
        for slot in slots { sparkle(at: slot.node.position, color: TargetSlot.mint, count: 14, spread: 80) }
        celebrate(big: def.number % Season.levelsPer == 0 && session?.mode == .level)
        publish { s in
            s.lastPerfect = perfect
            s.dailyReward = reward
            s.phase = .won(stars: stars)
        }
        #if DEBUG
        if Self.demo, session?.mode == .level {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { [weak self] in self?.session?.next() }
        }
        #endif
    }

    private func fail(message: String, near: Bool) {
        guard state != .lost, state != .won else { return }
        state = .lost
        lostAt = Date()
        endDrag()
        SFX.shared.play(.fail)
        Haptics.error()
        publish { $0.phase = .lost(message: message, near: near) }
    }

    // MARK: - Zamanlayıcı

    /// Dönen şekil ve kayan çekirdekler (yalnızca ilk kesime kadar).
    private func updateMotion(dt: CGFloat) {
        guard def.spin != 0 || def.orbitAmp > 0, pieces.count == 1, cutsLeft == def.cuts, let p = pieces.first else { return }
        motionT += dt
        let th = CGFloat(def.spin) * motionT
        let cs = cos(th), sn = sin(th)
        func rot(_ v: CGPoint) -> CGPoint { CGPoint(x: v.x * cs - v.y * sn, y: v.x * sn + v.y * cs) }
        p.poly = motionPoly.map { motionCenter + rot($0) }
        p.node.zRotation = th
        for i in p.cores.indices where i < motionCores.count {
            let ph = CGFloat(i) * 2.1
            let off = CGPoint(x: cos(motionT * 1.3 + ph), y: sin(motionT * 1.05 + ph)) * (def.orbitAmp * baseHalf)
            let local = motionCores[i] + off
            p.cores[i].center = motionCenter + rot(local)
            if i < coreNodes.count { coreNodes[i].position = local }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastTime = currentTime }
        guard lastTime > 0, state == .playing, def != nil, session?.phase != .paused else { return }
        guard !hintActive else { return }
        let dt = min(currentTime - lastTime, 0.1)
        updateMotion(dt: CGFloat(dt))
        guard let limit = def.timeLimit else { return }
        #if DEBUG
        if Self.demo { return }
        #endif
        timeLeft -= dt
        let f = max(0, CGFloat(timeLeft / limit))
        timerBar?.xScale = f
        timerBar?.color = f < 0.25 ? TargetSlot.coral : .white
        if timeLeft <= 0 {
            for p in pieces { p.node.run(.fadeAlpha(to: 0.4, duration: 0.3)) }
            fail(message: "Süre doldu", near: false)
        }
    }
}
