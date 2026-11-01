import SwiftUI
import SpriteKit

/// SwiftUI arayüzü ile SpriteKit sahnesi arasındaki köprü.
final class GameSession: ObservableObject {
    enum Phase: Equatable {
        case playing
        case paused
        case won(stars: Int)
        case lost(message: String, near: Bool)
    }

    enum Mode { case level, daily, flow }

    @Published var level: Int
    @Published var cutsLeft = 0
    @Published var totalCuts = 0
    @Published var phase: Phase = .playing { didSet { phaseChanged(from: oldValue) } }
    @Published var toast: String?
    @Published var dailyReward: (reward: Int, streak: Int, shield: Bool)?
    /// Üst üste başarılı bölüm sayısı (seri).
    @Published var combo = 0
    // Akış modu
    @Published var score = 0
    @Published var timeLeft: Double = 60
    @Published var flowOver = false
    @Published var newBest = false

    let mode: Mode
    var daily: Bool { mode == .daily }
    var lastPerfect = false
    private var flowIndex = 0
    private var timer: Timer?
    static let flowStartTime: Double = 60

    let scene: GameScene

    var palette: Palette { Palette.forLevel(level) }

    init(level: Int, mode: Mode = .level) {
        self.level = mode == .flow ? GameSession.flowLevel(0) : level
        self.mode = mode
        scene = GameScene()
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.session = self
        scene.load(level: self.level)
        if mode == .flow { startTimer() }
    }

    deinit { timer?.invalidate() }

    /// Akış modunda k. tur için bölüm: kolaydan zora yavaşça (S1-S3 aralığı; zamanlı sezonlar dışarıda).
    static func flowLevel(_ k: Int) -> Int { min(170, 2 + 3 * k) }

    func restart() {
        if mode == .flow, case .lost = phase { return }
        phase = .playing
        dailyReward = nil
        scene.load(level: level)
    }

    func next() {
        level = min(level + 1, LevelFactory.totalLevels)
        restart()
    }

    func pause() { if phase == .playing { phase = .paused } }
    func resume() { if phase == .paused { phase = .playing } }

    func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            if self?.toast == text { self?.toast = nil }
        }
    }

    // MARK: Faz değişimleri

    private func phaseChanged(from old: Phase) {
        switch phase {
        case .won(let stars):
            combo += 1
            guard mode == .flow else { return }
            let multiplier = min(combo, 10)
            let points = 100 + stars * 30 + multiplier * 25 + (lastPerfect ? 100 : 0)
            score += points
            timeLeft = min(120, timeLeft + (lastPerfect ? 5 : 3))
            showToast("+\(points)" + (combo >= 2 ? "  ·  x\(combo)" : ""))
            scheduleNextFlow()
        case .lost:
            combo = 0
            guard mode == .flow else { return }
            timeLeft -= 5
            showToast(L("−5 sn"))
            scheduleNextFlow()
        default:
            break
        }
    }

    // MARK: Akış modu

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, !self.flowOver, self.phase == .playing else { return }
            self.timeLeft -= 0.1
            if self.timeLeft <= 0 { self.endFlow() }
        }
    }

    private func scheduleNextFlow() {
        if timeLeft <= 0 { endFlow(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self] in
            guard let self, !self.flowOver else { return }
            if self.timeLeft <= 0 { self.endFlow(); return }
            self.flowIndex += 1
            self.level = GameSession.flowLevel(self.flowIndex)
            self.phase = .playing
            self.dailyReward = nil
            self.scene.load(level: self.level)
        }
    }

    private func endFlow() {
        guard !flowOver else { return }
        flowOver = true
        timeLeft = 0
        timer?.invalidate()
        newBest = PlayerProgress.shared.finishFlow(score: score)
        SFX.shared.play(newBest ? .perfect : .win)
        Haptics.success()
    }

    func restartFlow() {
        flowOver = false
        newBest = false
        score = 0
        combo = 0
        timeLeft = GameSession.flowStartTime
        flowIndex = 0
        level = GameSession.flowLevel(0)
        phase = .playing
        scene.load(level: level)
        timer?.invalidate()
        startTimer()
    }

    /// İpucu: hak varsa sahne en iyi ilk kesimi arar; bulunursa hak harcanır.
    func requestHint() {
        guard phase == .playing, mode != .flow else { return }
        guard PlayerProgress.shared.hints > 0 else {
            showToast(L("İpucu hakkın bitti. Günlük meydan okuma ve başarımlarla yenisini kazan."))
            return
        }
        scene.requestHint { [weak self] found in
            guard let self else { return }
            if found {
                _ = PlayerProgress.shared.useHint()
                SFX.shared.play(.tap)
            } else {
                self.showToast(L("Bu durumdan ipucu çıkarılamadı. Bölümü yeniden başlatmayı dene."))
            }
        }
    }
}
