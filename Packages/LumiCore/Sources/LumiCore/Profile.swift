import Foundation

/// Une grille commencée, gardée pour la reprendre plus tard.
public struct SavedGrid: Codable, Equatable, Sendable {
    public var key: String
    /// Marques du joueur (0 vide, 1 croix, 2 gemme).
    public var marks: [Int]
    public var elapsed: Double
    public var hintsUsed: Int
    /// Vies restantes (`nil` : sans limite ou ancienne sauvegarde).
    public var livesLeft: Int?
    /// « Continuer » utilisés (vidéo après avoir perdu toutes les vies).
    public var continues: Int?

    public init(key: String, marks: [Int], elapsed: Double, hintsUsed: Int, livesLeft: Int? = nil, continues: Int? = nil) {
        self.key = key
        self.marks = marks
        self.elapsed = elapsed
        self.hintsUsed = hintsUsed
        self.livesLeft = livesLeft
        self.continues = continues
    }
}

/// Résultat d'un niveau : meilleur temps, et s'il a été fini sans indice (médaille).
public struct LevelStat: Codable, Equatable, Sendable {
    public var bestTime: Int
    public var noHint: Bool

    public init(bestTime: Int, noHint: Bool) {
        self.bestTime = bestTime
        self.noHint = noHint
    }
}

/// Ce que rapporte une grille finie.
public struct Reward: Equatable, Sendable {
    public var hints = 0
    /// Série de jours (grille du jour seulement).
    public var streak = 0
    /// Premier passage (niveau jamais fini, grille du jour pas encore finie aujourd'hui).
    public var firstTime = false
    /// Thème débloqué par ce niveau.
    public var unlockedTheme: String?
    /// Meilleur temps battu (niveaux).
    public var newBest = false
    /// Finie sans indice (niveaux).
    public var noHint = false
    /// Chapitre terminé avec ce niveau (premier passage).
    public var chapterDone: Int?
    /// Indices offerts pour le chapitre terminé (déjà comptés dans `hints`).
    public var chapterHints = 0

    public init() {}
}

/// Tout ce que le jeu garde sur le téléphone : niveaux, indices, série, thèmes, réglages, grilles commencées.
/// Pas de compte ni de serveur. Les achats, eux, sont gardés par Apple (« Restaurer les achats »).
public struct Profile: Codable, Equatable, Sendable {
    public var firstLaunch: Date
    /// Plus haut niveau fini (le prochain à jouer est `levelsDone + 1`).
    public var levelsDone = 0
    public var hints = Economy.startingHints
    public var gridsSolved = 0

    // Achats et thèmes
    public var noAds = false
    public var ownedThemes: [String] = []
    public var theme = Catalog.defaultTheme
    /// Achats d'indices déjà crédités (identifiants de transaction Apple) : jamais deux fois.
    public var creditedTransactions: [UInt64] = []

    // Grille du jour
    public var lastDailyDay: String?
    public var streak = 0
    public var bestStreak = 0
    /// Meilleur temps (avec pénalités) de la dernière grille du jour finie.
    public var dailyTime: Int?
    /// Jour où la grille bonus a été débloquée, et jour où elle a été finie.
    public var bonusUnlockedDay: String?
    public var bonusDoneDay: String?
    /// Indices gagnés avec une pub aujourd'hui.
    public var adHintsDay: String?
    public var adHintsCount = 0

    /// Résultats des niveaux (clé : numéro du niveau).
    public var levelStats: [String: LevelStat] = [:]
    /// Grilles du mode Libre finies, par série (clé : « taille-difficulté »).
    public var freeSolved: [String: Int] = [:]
    /// Vies choisies pour le mode Libre (0 = sans limite).
    public var freeLives = 3

    // Grilles commencées (clé de `PuzzleKind`).
    public var saved: [SavedGrid] = []

    // Réglages
    public var soundOn = true
    public var hapticsOn = true
    public var autoCrosses = true
    /// Symboles dans les zones, en plus des couleurs (daltonisme).
    public var showSymbols = false
    public var tutorialDone = false

    public init(now: Date = Date()) {
        firstLaunch = now
    }

    // MARK: Niveaux

    public var nextLevel: Int { levelsDone + 1 }

    /// Un niveau se joue s'il est déjà fini (on le rejoue) ou si c'est le prochain.
    public func isUnlocked(_ level: Int) -> Bool { level >= 1 && level <= nextLevel }

    public func stat(_ level: Int) -> LevelStat? { levelStats[String(level)] }

    /// Niveau fini. Le meilleur temps et la médaille « sans indice » comptent à chaque fois ; la progression et les
    /// récompenses seulement pour le prochain niveau (les niveaux se débloquent dans l'ordre).
    @discardableResult
    public mutating func completeLevel(_ number: Int, seconds: Int = 0, hintsUsed: Int = 0) -> Reward {
        var reward = Reward()
        gridsSolved += 1
        reward.noHint = hintsUsed == 0
        let key = String(number)
        let previous = levelStats[key]
        let time = max(1, seconds)
        reward.newBest = previous != nil && time < previous!.bestTime
        levelStats[key] = LevelStat(bestTime: min(previous?.bestTime ?? time, time),
                                    noHint: (previous?.noHint ?? false) || reward.noHint)
        guard number == levelsDone + 1 else { return reward }
        levelsDone = number
        reward.firstTime = true
        reward.hints = Economy.levelReward(number)
        hints += reward.hints
        reward.unlockedTheme = Catalog.themes.first { $0.price == .level(number) }?.id
        if Chapters.isChallenge(number) {
            reward.chapterDone = Chapters.chapter(of: number)
            reward.chapterHints = Economy.chapterReward
            reward.hints += Economy.chapterReward
            hints += Economy.chapterReward
        }
        return reward
    }

    /// Niveaux finis sans indice dans un chapitre.
    public func medals(chapter: Int) -> Int {
        Chapters.levels(of: chapter).filter { stat($0)?.noHint == true }.count
    }

    // MARK: Mode Libre

    private static func freeKey(_ size: Int, _ difficulty: Difficulty) -> String { "\(size)-\(difficulty.rawValue)" }

    /// Prochaine grille de cette série (la grille commencée, s'il y en a une).
    public func freeKind(size: Int, difficulty: Difficulty) -> PuzzleKind {
        .free(size: size, difficulty: difficulty, number: (freeSolved[Self.freeKey(size, difficulty)] ?? 0) + 1)
    }

    public mutating func completeFree(size: Int, difficulty: Difficulty) {
        gridsSolved += 1
        freeSolved[Self.freeKey(size, difficulty), default: 0] += 1
    }

    // MARK: Grille du jour

    public func dailyDone(today: String) -> Bool { lastDailyDay == today }

    /// Grille du jour finie. Renvoie la récompense (vide si déjà finie aujourd'hui).
    @discardableResult
    public mutating func completeDaily(day: String, time: Int) -> Reward {
        var reward = Reward()
        gridsSolved += 1
        guard lastDailyDay != day else {
            dailyTime = min(dailyTime ?? time, time)
            reward.streak = streak
            return reward
        }
        streak = (lastDailyDay != nil && lastDailyDay == DayKey.previous(day)) ? streak + 1 : 1
        bestStreak = max(bestStreak, streak)
        lastDailyDay = day
        dailyTime = time
        reward.firstTime = true
        reward.streak = streak
        reward.hints = Economy.dailyReward(streak: streak)
        hints += reward.hints
        return reward
    }

    /// Série affichée aujourd'hui : elle tient tant que la grille d'hier ou d'aujourd'hui a été finie.
    public func currentStreak(today: String) -> Int {
        guard let last = lastDailyDay, last == today || last == DayKey.previous(today) else { return 0 }
        return streak
    }

    // MARK: Grille bonus

    /// La grille bonus se débloque avec une pub, une fois la grille du jour finie.
    public func canUnlockBonus(today: String) -> Bool {
        dailyDone(today: today) && bonusUnlockedDay != today
    }

    public func bonusAvailable(today: String) -> Bool { bonusUnlockedDay == today && bonusDoneDay != today }

    public mutating func unlockBonus(today: String) { bonusUnlockedDay = today }

    @discardableResult
    public mutating func completeBonus(day: String) -> Reward {
        var reward = Reward()
        gridsSolved += 1
        guard bonusDoneDay != day else { return reward }
        bonusDoneDay = day
        reward.firstTime = true
        reward.hints = Economy.bonusReward
        hints += reward.hints
        return reward
    }

    // MARK: Indices

    /// Utilise un indice. Renvoie `false` s'il n'en reste pas.
    public mutating func useHint() -> Bool {
        guard hints > 0 else { return false }
        hints -= 1
        return true
    }

    public func canEarnAdHint(today: String) -> Bool {
        adHintsDay != today || adHintsCount < Economy.maxAdHintsPerDay
    }

    public mutating func earnAdHint(today: String) {
        if adHintsDay != today {
            adHintsDay = today
            adHintsCount = 0
        }
        adHintsCount += 1
        hints += Economy.adHint
    }

    // MARK: Thèmes

    public func owns(_ theme: ThemeSkin) -> Bool {
        switch theme.price {
        case .free: true
        case .level(let number): levelsDone >= number
        case .store: ownedThemes.contains(theme.id)
        }
    }

    public mutating func select(_ theme: ThemeSkin) {
        guard owns(theme) else { return }
        self.theme = theme.id
    }

    // MARK: Grilles commencées

    public func saved(_ key: String) -> SavedGrid? { saved.first { $0.key == key } }

    /// Grilles commencées gardées au plus (les plus anciennes partent).
    public static let maxSaved = 6

    /// Garde une grille commencée.
    public mutating func save(_ grid: SavedGrid) {
        saved.removeAll { $0.key == grid.key }
        saved.insert(grid, at: 0)
        if saved.count > Self.maxSaved { saved.removeLast(saved.count - Self.maxSaved) }
    }

    public mutating func forget(_ key: String) {
        saved.removeAll { $0.key == key }
    }

    // MARK: Lecture tolérante

    // Chaque champ a une valeur par défaut : un profil enregistré par une ancienne version se lit toujours,
    // même quand on ajoute des champs. Ne jamais renommer une clé existante (le profil serait perdu).
    private enum CodingKeys: String, CodingKey {
        case firstLaunch, levelsDone, hints, gridsSolved, noAds, ownedThemes, theme, creditedTransactions, lastDailyDay,
             streak, bestStreak, dailyTime, bonusUnlockedDay, bonusDoneDay, adHintsDay, adHintsCount, saved, soundOn,
             hapticsOn, autoCrosses, showSymbols, tutorialDone, levelStats, freeSolved, freeLives
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Profile()
        firstLaunch = try c.decodeIfPresent(Date.self, forKey: .firstLaunch) ?? base.firstLaunch
        levelsDone = try c.decodeIfPresent(Int.self, forKey: .levelsDone) ?? base.levelsDone
        hints = try c.decodeIfPresent(Int.self, forKey: .hints) ?? base.hints
        gridsSolved = try c.decodeIfPresent(Int.self, forKey: .gridsSolved) ?? base.gridsSolved
        noAds = try c.decodeIfPresent(Bool.self, forKey: .noAds) ?? base.noAds
        ownedThemes = try c.decodeIfPresent([String].self, forKey: .ownedThemes) ?? base.ownedThemes
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? base.theme
        creditedTransactions = try c.decodeIfPresent([UInt64].self, forKey: .creditedTransactions) ?? base.creditedTransactions
        lastDailyDay = try c.decodeIfPresent(String.self, forKey: .lastDailyDay)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? base.streak
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? base.bestStreak
        dailyTime = try c.decodeIfPresent(Int.self, forKey: .dailyTime)
        bonusUnlockedDay = try c.decodeIfPresent(String.self, forKey: .bonusUnlockedDay)
        bonusDoneDay = try c.decodeIfPresent(String.self, forKey: .bonusDoneDay)
        adHintsDay = try c.decodeIfPresent(String.self, forKey: .adHintsDay)
        adHintsCount = try c.decodeIfPresent(Int.self, forKey: .adHintsCount) ?? base.adHintsCount
        saved = try c.decodeIfPresent([SavedGrid].self, forKey: .saved) ?? base.saved
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? base.soundOn
        hapticsOn = try c.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? base.hapticsOn
        autoCrosses = try c.decodeIfPresent(Bool.self, forKey: .autoCrosses) ?? base.autoCrosses
        showSymbols = try c.decodeIfPresent(Bool.self, forKey: .showSymbols) ?? base.showSymbols
        tutorialDone = try c.decodeIfPresent(Bool.self, forKey: .tutorialDone) ?? base.tutorialDone
        levelStats = try c.decodeIfPresent([String: LevelStat].self, forKey: .levelStats) ?? base.levelStats
        freeSolved = try c.decodeIfPresent([String: Int].self, forKey: .freeSolved) ?? base.freeSolved
        freeLives = try c.decodeIfPresent(Int.self, forKey: .freeLives) ?? base.freeLives
    }
}
