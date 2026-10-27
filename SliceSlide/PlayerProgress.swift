import Foundation

/// Kalıcı ilerleme: bölümler, yıldızlar, ipucu hakkı, günlük seri, istatistikler, başarımlar.
final class PlayerProgress: ObservableObject {
    static let shared = PlayerProgress()

    @Published private(set) var unlocked: Int
    @Published private(set) var stars: [Int: Int]
    @Published private(set) var selectedSkin: Int
    @Published private(set) var hints: Int
    @Published private(set) var bestStreak: Int
    @Published private(set) var dailyWins: Int
    @Published private(set) var totalCuts: Int
    @Published private(set) var perfects: Int
    @Published private(set) var bestFlow: Int
    @Published private(set) var shields: Int
    @Published private(set) var lastChest: String
    @Published private(set) var fragments: Int
    @Published private(set) var trailsUnlocked: Set<Int>
    @Published private(set) var themesDropped: Set<Int>
    @Published private(set) var selectedTrail: Int
    @Published private(set) var selectedTheme: Int
    @Published private(set) var selectedSet: Int
    @Published private(set) var chestBoosted: Bool
    private var chestTierDay: String
    private var chestTierValue: Int
    @Published private(set) var achieved: Set<String>
    /// Gösterilmeyi bekleyen yeni başarımlar.
    @Published var toasts: [Achievement] = []
    @Published private(set) var lastDaily: String
    private var streakStored: Int
    let launchIndex: Int

    private let d = UserDefaults.standard

    private init() {
        unlocked = max(1, d.integer(forKey: "unlocked"))
        let raw = d.dictionary(forKey: "stars") as? [String: Int] ?? [:]
        stars = raw.reduce(into: [:]) { $0[Int($1.key) ?? 0] = $1.value }
        selectedSkin = d.object(forKey: "skin") == nil ? -1 : d.integer(forKey: "skin")
        hints = d.object(forKey: "hints") == nil ? 3 : d.integer(forKey: "hints")
        bestStreak = d.integer(forKey: "bestStreak")
        dailyWins = d.integer(forKey: "dailyWins")
        totalCuts = d.integer(forKey: "totalCuts")
        perfects = d.integer(forKey: "perfects")
        bestFlow = d.integer(forKey: "bestFlow")
        shields = d.integer(forKey: "shields")
        lastChest = d.string(forKey: "lastChest") ?? ""
        fragments = d.integer(forKey: "fragments")
        trailsUnlocked = Set((d.array(forKey: "trails") as? [Int]) ?? [])
        themesDropped = Set((d.array(forKey: "themesDropped") as? [Int]) ?? [])
        selectedTrail = d.integer(forKey: "trail")
        selectedTheme = d.object(forKey: "theme") == nil ? -1 : d.integer(forKey: "theme")
        selectedSet = d.object(forKey: "themeSet") == nil ? -1 : d.integer(forKey: "themeSet")
        chestBoosted = d.bool(forKey: "chestBoosted")
        chestTierDay = d.string(forKey: "chestTierDay") ?? ""
        chestTierValue = d.integer(forKey: "chestTier")
        achieved = Set(d.stringArray(forKey: "achieved") ?? [])
        lastDaily = d.string(forKey: "lastDaily") ?? ""
        streakStored = d.integer(forKey: "streak")
        let n = d.integer(forKey: "launchCount")
        launchIndex = n
        d.set(n + 1, forKey: "launchCount")
    }

    // MARK: Türetilmiş değerler

    var totalStars: Int { stars.values.reduce(0, +) }
    var completedCount: Int { stars.count }
    var seasonsDone: Int { (0..<Season.all.count).filter { seasonDone($0) }.count }
    func seasonDone(_ s: Int) -> Bool { stars[(s + 1) * Season.levelsPer] != nil }

    func starsIn(season s: Int) -> Int {
        (1...Season.levelsPer).reduce(0) { $0 + (stars[s * Season.levelsPer + $1] ?? 0) }
    }

    var dailyDone: Bool { lastDaily == DailyChallenge.key(Date()) }

    private func dayKey(_ offset: Int) -> String {
        DailyChallenge.key(Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date())
    }

    /// Bugün ya da dün tamamlandıysa seri geçerlidir; bir gün kaçırıldıysa Seri Kalkanı kurtarır.
    var currentStreak: Int {
        if lastDaily == dayKey(0) || lastDaily == dayKey(-1) { return streakStored }
        if lastDaily == dayKey(-2), shields > 0 { return streakStored }
        return 0
    }

    var chestReady: Bool { lastChest != dayKey(0) }

    // MARK: Olaylar

    func complete(level: Int, stars s: Int, perfect: Bool) {
        let first = stars[level] == nil
        stars[level] = max(stars[level] ?? 0, s)
        unlocked = min(LevelFactory.totalLevels, max(unlocked, level + 1))
        if first {
            if level % Season.levelsPer == 0 { hints += 3 }       // sezon sonu
            else if level % 10 == 0 { hints += 1 }                // her 10 bölümde bir
        }
        if perfect { perfects += 1 }
        d.set(unlocked, forKey: "unlocked")
        d.set(stars.reduce(into: [String: Int]()) { $0[String($1.key)] = $1.value }, forKey: "stars")
        saveStats()
        afterEvent()
    }

    /// Günlük bölüm bitti. Ödül günde yalnızca bir kez verilir.
    @discardableResult
    func completeDaily(perfect: Bool) -> (reward: Int, streak: Int, shield: Bool)? {
        if perfect { perfects += 1 }
        guard !dailyDone else { saveStats(); afterEvent(); return nil }
        var usedShield = false
        if lastDaily == dayKey(-1) {
            streakStored += 1
        } else if lastDaily == dayKey(-2), shields > 0 {
            shields -= 1
            usedShield = true
            streakStored += 1
        } else {
            streakStored = 1
        }
        d.set(shields, forKey: "shields")
        bestStreak = max(bestStreak, streakStored)
        lastDaily = DailyChallenge.key(Date())
        dailyWins += 1
        let reward = streakStored % 7 == 0 ? 3 : 1
        hints += reward
        d.set(lastDaily, forKey: "lastDaily")
        d.set(streakStored, forKey: "streak")
        saveStats()
        afterEvent()
        Reminders.requestIfNeeded()
        return (reward, streakStored, usedShield)
    }

    /// Akış modu bitti; yeni rekor ise true döner.
    func finishFlow(score: Int) -> Bool {
        let isBest = score > bestFlow
        if isBest { bestFlow = score; d.set(bestFlow, forKey: "bestFlow") }
        afterEvent()
        GameCenter.shared.submitFlow(score: bestFlow)
        return isBest && score > 0
    }

    // MARK: Kozmetik kilitleri

    func skinUnlocked(_ id: Int) -> Bool {
        guard Skin.all.indices.contains(id) else { return false }
        switch Skin.all[id].source {
        case .season(let s): return seasonDone(s)
        case .fragments(let k): return fragments >= Skin.fragmentsPerSkin * k
        }
    }
    func trailUnlocked(_ id: Int) -> Bool { id == 0 || trailsUnlocked.contains(id) }
    func themeUnlocked(_ id: Int) -> Bool { seasonDone(id) || themesDropped.contains(id) }

    func selectTrail(_ i: Int) { selectedTrail = i; d.set(i, forKey: "trail") }
    func selectTheme(_ i: Int) { selectedTheme = i; d.set(i, forKey: "theme") }

    func setUnlocked(_ id: Int) -> Bool {
        guard ThemeSet.all.indices.contains(id) else { return false }
        #if DEBUG
        return true   // test derlemesinde tüm setler açık
        #else
        return seasonDone(ThemeSet.all[id].unlockSeason)
        #endif
    }
    func selectSet(_ i: Int) { selectedSet = i; d.set(i, forKey: "themeSet") }

    /// Bir sonraki kristal skinine kalan parça (0..6) ve toplam hedef.
    var fragmentProgress: (have: Int, need: Int) { (fragments % Skin.fragmentsPerSkin, Skin.fragmentsPerSkin) }
    var nextFragmentSkin: Skin? {
        let k = fragments / Skin.fragmentsPerSkin + 1
        return Skin.all.first { if case .fragments(let n) = $0.source { return n == k } else { return false } }
    }

    // MARK: Günlük sandık

    /// Bugünün sandık seviyesi (0 Normal, 1 Nadir, 2 Destansı). Günde bir kez belirlenir.
    func todaysChestTier() -> Int {
        let today = dayKey(0)
        if chestTierDay != today {
            let r = Int.random(in: 0..<100)
            var t = r < 70 ? 0 : (r < 95 ? 1 : 2)
            if currentStreak >= 7 { t = max(1, t) }        // 7+ günlük seri: en az Nadir
            chestTierDay = today
            chestTierValue = t
            chestBoosted = false
            d.set(today, forKey: "chestTierDay")
            d.set(t, forKey: "chestTier")
            d.set(false, forKey: "chestBoosted")
            objectWillChange.send()
        }
        return chestTierValue
    }

    var chestBoostAvailable: Bool { chestReady && !chestBoosted && todaysChestTier() < 2 }

    /// Reklam sonrası: %50 ihtimalle sandık bir üst seviyeye çıkar. Tek hak.
    func boostChest() -> Bool {
        let tier = todaysChestTier()
        guard chestReady, !chestBoosted, tier < 2 else { return false }
        chestBoosted = true
        d.set(true, forKey: "chestBoosted")
        let success = Bool.random()
        if success {
            chestTierValue = tier + 1
            d.set(chestTierValue, forKey: "chestTier")
        }
        objectWillChange.send()
        return success
    }

    private func lockedCosmetic() -> ChestItem.Kind? {
        var pool: [ChestItem.Kind] = []
        for t in Trail.all where !trailUnlocked(t.id) { pool.append(.trail(t.id)) }
        for s in Season.all where !themeUnlocked(s.index) { pool.append(.theme(s.index)) }
        return pool.randomElement()
    }

    /// Günlük sandığı açar (günde bir kez). Seviye, ödül çeşidini ve miktarını belirler.
    func openChest() -> ChestResult? {
        guard chestReady else { return nil }
        let tier = todaysChestTier()
        let jackpot = Int.random(in: 0..<100) < 2
        var kinds: [ChestItem.Kind] = []
        func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }

        switch tier {
        case 0:
            kinds.append(.hints(Int.random(in: 1...2)))
            if chance(0.25) { kinds.append(.fragments(1)) }
            if chance(0.08) { kinds.append(.shield(1)) }
        case 1:
            kinds.append(.hints(Int.random(in: 3...4)))
            kinds.append(.fragments(Int.random(in: 1...2)))
            if chance(0.4) { kinds.append(.shield(1)) }
            if chance(0.15), let c = lockedCosmetic() { kinds.append(c) }
        default:
            kinds.append(.hints(Int.random(in: 5...7)))
            kinds.append(.fragments(Int.random(in: 2...3)))
            kinds.append(.shield(1))
            if chance(0.35), let c = lockedCosmetic() { kinds.append(c) }
        }
        if currentStreak >= 7, case .hints(let n)? = kinds.first { kinds[0] = .hints(n + 1) }
        if jackpot {   // Çifte sandık: miktarlar iki katı + garanti kozmetik
            kinds = kinds.map {
                switch $0 {
                case .hints(let n): return .hints(n * 2)
                case .fragments(let n): return .fragments(n * 2)
                case .shield(let n): return .shield(n * 2)
                default: return $0
                }
            }
            if !kinds.contains(where: { if case .trail = $0 { return true }; if case .theme = $0 { return true }; return false }),
               let c = lockedCosmetic() { kinds.append(c) }
        }

        // Uygula
        let skinsBefore = fragments / Skin.fragmentsPerSkin
        var items: [ChestItem] = []
        for k in kinds {
            switch k {
            case .hints(let n): hints += n
            case .shield(let n): shields += n
            case .fragments(let n): fragments += n
            case .trail(let t): trailsUnlocked.insert(t)
            case .theme(let t): themesDropped.insert(t)
            case .skin: break
            }
            items.append(ChestItem(kind: k))
        }
        let skinsAfter = fragments / Skin.fragmentsPerSkin
        if skinsAfter > skinsBefore {
            for k in (skinsBefore + 1)...skinsAfter {
                if let s = Skin.all.first(where: { if case .fragments(let n) = $0.source { return n == k } else { return false } }) {
                    items.append(ChestItem(kind: .skin(s.id)))
                }
            }
        }
        lastChest = dayKey(0)
        d.set(lastChest, forKey: "lastChest")
        d.set(shields, forKey: "shields")
        d.set(fragments, forKey: "fragments")
        d.set(Array(trailsUnlocked), forKey: "trails")
        d.set(Array(themesDropped), forKey: "themesDropped")
        saveStats()
        afterEvent()
        Reminders.requestIfNeeded()
        return ChestResult(tier: tier, jackpot: jackpot, items: items)
    }

    func addCut() {
        totalCuts += 1
        if totalCuts % 5 == 0 { d.set(totalCuts, forKey: "totalCuts") }
    }

    func useHint() -> Bool {
        guard hints > 0 else { return false }
        hints -= 1
        d.set(hints, forKey: "hints")
        return true
    }

    func selectSkin(_ i: Int) {
        selectedSkin = i
        d.set(i, forKey: "skin")
    }

    // MARK: Yardımcılar

    private func saveStats() {
        d.set(hints, forKey: "hints")
        d.set(bestStreak, forKey: "bestStreak")
        d.set(dailyWins, forKey: "dailyWins")
        d.set(totalCuts, forKey: "totalCuts")
        d.set(perfects, forKey: "perfects")
    }

    private func afterEvent() {
        for a in Achievement.all where !achieved.contains(a.id) && a.value(self) >= a.goal {
            achieved.insert(a.id)
            hints += 1
            toasts.append(a)
            GameCenter.shared.report(achievement: a.id)
        }
        d.set(Array(achieved), forKey: "achieved")
        saveStats()
        GameCenter.shared.submit(totalStars: totalStars, highestLevel: unlocked)
    }

    #if DEBUG
    /// Yalnızca test derlemesinde: bugünkü sandığı yeniden açılabilir yap.
    func debugResetChest() {
        lastChest = ""
        d.set("", forKey: "lastChest")
        chestTierDay = ""
        d.set("", forKey: "chestTierDay")
        chestBoosted = false
        d.set(false, forKey: "chestBoosted")
        objectWillChange.send()
    }

    func debugAddFragments(_ n: Int) {
        fragments += n
        d.set(fragments, forKey: "fragments")
    }

    /// Yalnızca test derlemesinde: bugünkü günlük meydan okumayı yeniden oynanabilir yap.
    func debugResetDaily() {
        lastDaily = ""
        streakStored = 0
        d.set("", forKey: "lastDaily")
        d.set(0, forKey: "streak")
        objectWillChange.send()
    }

    func debugAddHints(_ n: Int) {
        hints += n
        d.set(hints, forKey: "hints")
    }
    #endif
}
