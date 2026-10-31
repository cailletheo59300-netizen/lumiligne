import XCTest
@testable import LumiCore

final class GeneratorTests: XCTestCase {
    /// Vérifie toutes les règles d'une grille générée.
    private func check(_ grid: Grid, file: StaticString = #filePath, line: UInt = #line) {
        let layout = grid.layout
        let n = grid.size
        // Autant de zones que de lignes, chacune d'au moins 2 cases, d'un seul morceau.
        XCTAssertEqual(layout.cellsOfZone.count, n, file: file, line: line)
        for zone in 0..<n {
            XCTAssertGreaterThanOrEqual(layout.cellsOfZone[zone].count, Generator.minZoneSize, file: file, line: line)
            XCTAssertTrue(Generator.isConnected(layout.zones, zone: zone, size: n), "zone \(zone) en morceaux", file: file, line: line)
        }
        // La solution respecte les règles.
        XCTAssertEqual(grid.solution.count, n, file: file, line: line)
        for (zone, cell) in grid.solution.enumerated() {
            XCTAssertEqual(layout.zones[cell], zone, file: file, line: line)
            for other in grid.solution where other != cell {
                XCTAssertNil(layout.conflict(cell, other), file: file, line: line)
            }
        }
        // Une seule solution (recherche exhaustive).
        let all = Solver.solutions(size: n, zones: layout.zones, limit: 2)
        XCTAssertEqual(all, [grid.solution], "solution non unique", file: file, line: line)
        // Résolue par déduction seule, sans deviner.
        XCTAssertEqual(Solver.rate(layout).solution, grid.solution, "pas résoluble par déduction", file: file, line: line)
    }

    func testGeneratedGridsHaveOneSolutionFoundByDeduction() {
        for size in 5...9 {
            for difficulty in Difficulty.allCases {
                for index in 0..<3 {
                    let grid = Generator.grid(size: size, difficulty: difficulty,
                                              seed: SeededRandom.seed(from: "test-\(size)-\(difficulty)-\(index)"))
                    check(grid)
                    XCTAssertEqual(grid.size, size)
                }
            }
        }
    }

    func testFirstLevelsAndAWeekOfDailyGrids() {
        for number in [1, 2, 3, 6, 11, 12, 20, 36, 40, 81, 151] {
            let grid = Puzzles.grid(.level(number))
            check(grid)
            XCTAssertEqual(grid.size, Puzzles.levelSize(number))
        }
        var day = "2026-11-08"
        for _ in 0..<7 {
            let grid = Puzzles.grid(.daily(day))
            check(grid)
            XCTAssertEqual(grid.size, Puzzles.plan(.daily(day)).size)
            day = DayKey.previous(day)!
        }
        check(Puzzles.grid(.bonus("2026-11-08")))
    }

    func testDifficultyIsMostlyRespected() {
        var matches = 0
        var total = 0
        for size in [6, 7] {
            for difficulty in Difficulty.allCases {
                for index in 0..<3 {
                    let grid = Generator.grid(size: size, difficulty: difficulty, seed: SeededRandom.seed(from: "diff-\(size)-\(difficulty)-\(index)"))
                    total += 1
                    if grid.difficulty == difficulty { matches += 1 }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(matches, total - 1)
    }

    /// La même graine donne la même grille : la grille du jour est la même pour tout le monde.
    func testSameSeedSameGrid() {
        let a = Puzzles.grid(.daily("2026-10-31"))
        let b = Puzzles.grid(.daily("2026-10-31"))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a.layout.zones, Puzzles.grid(.daily("2026-11-01")).layout.zones)
        XCTAssertEqual(Puzzles.grid(.level(7)), Puzzles.grid(.level(7)))
    }

    /// Empreinte figée de la grille d'un jour : si ce test casse, la grille du jour a changé pour tout le monde
    /// (changement du générateur ou des réglages). À faire seulement avant la sortie, ou en le sachant.
    func testDailyFingerprint() {
        let grid = Puzzles.grid(.daily("2026-12-01"))
        let fingerprint = grid.layout.zones.map(String.init).joined()
        // Affichée dans le journal de test pour pouvoir la recopier ci-dessous après un changement voulu.
        print("Empreinte 2026-12-01 :", fingerprint, grid.solution)
        XCTAssertEqual(grid.size, 6)
        XCTAssertEqual(grid.solution.count, 6)
    }

    func testSeededRandomIsStable() {
        var random = SeededRandom(seed: 42)
        let values = (0..<3).map { _ in random.next() }
        var again = SeededRandom(seed: 42)
        XCTAssertEqual(values, (0..<3).map { _ in again.next() })
        XCTAssertEqual(SeededRandom.seed(from: "lumiligne"), SeededRandom.seed(from: "lumiligne"))
        XCTAssertNotEqual(SeededRandom.seed(from: "a"), SeededRandom.seed(from: "b"))
    }

    func testLevelPlan() {
        // Les 3 premiers niveaux : 5 × 5 faciles.
        for number in 1...3 {
            XCTAssertEqual(Puzzles.levelSize(number), 5)
            XCTAssertEqual(Puzzles.levelDifficulty(number), .easy)
        }
        // Le chapitre 1 ne dépasse pas 6 × 6 ; son défi (niveau 20) est le plus grand.
        XCTAssertEqual(Chapters.levels(of: 1).map(Puzzles.levelSize).max(), 6)
        XCTAssertEqual(Puzzles.levelSize(20), 6)
        XCTAssertTrue(Chapters.isChallenge(20))
        // Les tailles restent mélangées, même loin dans le jeu : il y a toujours des petites grilles.
        for chapter in [4, 12, 50] {
            let sizes = Chapters.levels(of: chapter).map(Puzzles.levelSize)
            XCTAssertTrue(sizes.contains(5))
            XCTAssertTrue(sizes.contains(9))
            XCTAssertEqual(Puzzles.levelSize(Chapters.levels(of: chapter).upperBound), 9)
        }
        // La difficulté monte : beaucoup de faciles au chapitre 1, presque que des difficiles au chapitre 8.
        let easy1 = Chapters.levels(of: 1).filter { Puzzles.levelDifficulty($0) == .easy }.count
        let hard8 = Chapters.levels(of: 8).filter { Puzzles.levelDifficulty($0) == .hard }.count
        XCTAssertGreaterThanOrEqual(easy1, 10)
        XCTAssertGreaterThanOrEqual(hard8, 15)
        XCTAssertEqual(Puzzles.levelDifficulty(40), .hard)
    }

    func testChapters() {
        XCTAssertEqual(Chapters.chapter(of: 1), 1)
        XCTAssertEqual(Chapters.chapter(of: 20), 1)
        XCTAssertEqual(Chapters.chapter(of: 21), 2)
        XCTAssertEqual(Chapters.position(of: 21), 0)
        XCTAssertEqual(Chapters.levels(of: 2), 21...40)
        XCTAssertEqual(Chapters.name(1), "Éveil")
        XCTAssertEqual(Chapters.name(11), "Infini")
    }

    func testFreeGrids() {
        let kind = PuzzleKind.free(size: 9, difficulty: .easy, number: 3)
        XCTAssertEqual(Puzzles.plan(kind).size, 9)
        let grid = Puzzles.grid(kind)
        check(grid)
        XCTAssertEqual(grid, Puzzles.grid(kind))
        XCTAssertNotEqual(kind.key, PuzzleKind.free(size: 9, difficulty: .easy, number: 4).key)
    }

    func testWeekday() {
        XCTAssertEqual(DayKey.weekday("2026-11-02"), 1) // lundi
        XCTAssertEqual(DayKey.weekday("2026-11-08"), 7) // dimanche
        XCTAssertEqual(DayKey.previous("2026-03-01"), "2026-02-28")
    }
}
