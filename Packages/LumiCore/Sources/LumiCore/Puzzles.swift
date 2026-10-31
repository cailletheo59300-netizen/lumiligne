import Foundation

/// Jours de la grille du jour. Un jour va de minuit à minuit en heure universelle (UTC), soit 1 h ou 2 h du matin en
/// France : tout le monde a la même grille en même temps, comme le classement quotidien de Game Center (00:00 UTC).
public enum DayKey {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// « 2026-10-31 ».
    public static func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func today(_ now: Date = Date()) -> String { key(for: now) }

    /// Le jour d'avant (« 2026-10-30 » pour « 2026-10-31 »).
    public static func previous(_ day: String) -> String? {
        guard let date = date(of: day), let before = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        return key(for: before)
    }

    public static func date(of day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Jour de la semaine : 1 = lundi … 7 = dimanche.
    public static func weekday(_ day: String) -> Int {
        guard let date = date(of: day) else { return 1 }
        let sundayFirst = calendar.component(.weekday, from: date) // 1 = dimanche
        return sundayFirst == 1 ? 7 : sundayFirst - 1
    }

    /// Temps restant avant la prochaine grille du jour.
    public static func secondsUntilNextDay(_ now: Date = Date()) -> TimeInterval {
        let start = calendar.startOfDay(for: now)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return max(0, next.timeIntervalSince(now))
    }
}

/// Les sortes de grilles.
public enum PuzzleKind: Equatable, Hashable, Sendable {
    /// Niveau numéroté (1, 2, 3…) du parcours. Les niveaux finis se rejouent.
    case level(Int)
    /// Grille du jour, la même pour tout le monde.
    case daily(String)
    /// Grille bonus du jour, débloquée avec une pub une fois la grille du jour finie.
    case bonus(String)
    /// Mode Libre : taille et difficulté au choix. `number` = numéro de la grille dans cette série (1, 2, 3…).
    case free(size: Int, difficulty: Difficulty, number: Int)

    /// Clé de sauvegarde (grille commencée).
    public var key: String {
        switch self {
        case .level(let number): "level-\(number)"
        case .daily(let day): "daily-\(day)"
        case .bonus(let day): "bonus-\(day)"
        case .free(let size, let difficulty, let number): "free-\(size)-\(difficulty.rawValue)-\(number)"
        }
    }

    public var title: String {
        switch self {
        case .level(let number): "Niveau \(number)"
        case .daily: "Grille du jour"
        case .bonus: "Grille bonus"
        case .free: "Libre"
        }
    }
}

/// Le parcours : des chapitres de 20 niveaux, sans fin. Chaque chapitre mélange les tailles (petites grilles rapides,
/// moyennes, grandes) ; d'un chapitre à l'autre, c'est surtout la difficulté qui monte. Le 20e niveau d'un chapitre
/// est un « défi » : la plus grande grille du chapitre, à sa difficulté la plus haute.
public enum Chapters {
    public static let levelsPerChapter = 20

    public static func chapter(of level: Int) -> Int { (max(1, level) - 1) / levelsPerChapter + 1 }

    /// Place du niveau dans son chapitre, de 0 à 19.
    public static func position(of level: Int) -> Int { (max(1, level) - 1) % levelsPerChapter }

    public static func firstLevel(of chapter: Int) -> Int { (max(1, chapter) - 1) * levelsPerChapter + 1 }

    public static func levels(of chapter: Int) -> ClosedRange<Int> {
        firstLevel(of: chapter)...(firstLevel(of: chapter) + levelsPerChapter - 1)
    }

    public static func isChallenge(_ level: Int) -> Bool { position(of: level) == levelsPerChapter - 1 }

    private static let names = ["Éveil", "Lueur", "Prisme", "Reflet", "Éclat", "Aurore", "Zénith", "Comète",
                                "Nébuleuse", "Constellation"]

    /// Nom du chapitre (« Éveil », « Lueur »…), puis « Infini » après le 10e.
    public static func name(_ chapter: Int) -> String {
        chapter >= 1 && chapter <= names.count ? names[chapter - 1] : "Infini"
    }
}

/// Taille, difficulté et graine de chaque grille. Changer une valeur ici change les grilles des joueurs :
/// à faire avant la sortie (voir docs/REGLES.md).
public enum Puzzles {
    public struct Plan: Equatable, Sendable {
        public let size: Int
        public let difficulty: Difficulty
        public let seed: UInt64
    }

    public static func plan(_ kind: PuzzleKind) -> Plan {
        switch kind {
        case .level(let number):
            return Plan(size: levelSize(number), difficulty: levelDifficulty(number),
                        seed: SeededRandom.seed(from: "lumiligne-level-\(number)"))
        case .daily(let day):
            // Du lundi au dimanche : la grille grandit un peu au fil de la semaine.
            let week: [(Int, Difficulty)] = [(6, .medium), (6, .hard), (7, .medium), (7, .hard), (7, .hard), (8, .medium), (8, .hard)]
            let (size, difficulty) = week[DayKey.weekday(day) - 1]
            return Plan(size: size, difficulty: difficulty, seed: SeededRandom.seed(from: "lumiligne-daily-\(day)"))
        case .bonus(let day):
            return Plan(size: 8, difficulty: .hard, seed: SeededRandom.seed(from: "lumiligne-bonus-\(day)"))
        case .free(let size, let difficulty, let number):
            return Plan(size: min(9, max(5, size)), difficulty: difficulty,
                        seed: SeededRandom.seed(from: "lumiligne-free-\(size)-\(difficulty.rawValue)-\(number)"))
        }
    }

    public static func grid(_ kind: PuzzleKind) -> Grid {
        let plan = plan(kind)
        return Generator.grid(size: plan.size, difficulty: plan.difficulty, seed: plan.seed)
    }

    /// Tailles permises dans le mode Libre.
    public static let freeSizes = Array(5...9)

    /// Taille d'un niveau. Dans un chapitre, le rythme alterne : petite, moyenne, petite, grande…
    /// La plus grande taille du chapitre grandit avec les chapitres (6 × 6 au chapitre 1, jusqu'à 9 × 9 au chapitre 4),
    /// mais les petites grilles restent toujours là.
    public static func levelSize(_ number: Int) -> Int {
        let chapter = Chapters.chapter(of: number)
        let position = Chapters.position(of: number)
        let large = min(9, 5 + chapter)
        // Les 3 premiers niveaux du jeu, pour apprendre : 5 × 5.
        if chapter == 1, position < 3 { return 5 }
        if Chapters.isChallenge(number) { return large }
        let small = chapter >= 4 && (position / 4) % 2 == 1 ? 6 : 5
        let medium = (small + large + 1) / 2
        switch position % 4 {
        case 0, 2: return small
        case 1: return medium
        default: return large
        }
    }

    /// Difficulté d'un niveau : elle monte dans chaque chapitre, et d'un chapitre à l'autre.
    public static func levelDifficulty(_ number: Int) -> Difficulty {
        let chapter = Chapters.chapter(of: number)
        let t = Chapters.position(of: number)
        if Chapters.isChallenge(number) { return chapter == 1 ? .medium : .hard }
        switch chapter {
        case 1: return t < 12 ? .easy : .medium
        case 2: return t < 6 ? .easy : (t < 15 ? .medium : .hard)
        case 3: return t < 3 ? .easy : (t < 11 ? .medium : .hard)
        case 4, 5: return t < 9 ? .medium : .hard
        default: return t % 5 == 0 ? .medium : .hard
        }
    }
}
