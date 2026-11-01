import Foundation
import SwiftUI
import LumiCore

/// Une grille en cours : marques du joueur, chronomètre, indices, messages, victoire.
/// Les règles sont dans `LumiCore.Board` ; ici, on relie les gestes aux sons, vibrations, animations et sauvegardes.
@MainActor
@Observable
final class GameSession: Identifiable {
    let id = UUID()
    let kind: PuzzleKind
    private(set) var board: Board
    private(set) var hintsUsed: Int

    /// Message sous la grille (explication d'un indice ou d'une erreur).
    private(set) var message: String?
    private(set) var messageIsError = false
    /// Cases montrées par le dernier indice (et un compteur pour relancer l'animation).
    private(set) var highlight: [Int] = []
    private(set) var highlightToken = 0
    /// Zone qui vient d'être résolue (éclat), avec un compteur pour relancer l'animation.
    private(set) var flashZone: Int?
    private(set) var flashToken = 0

    /// Vies de la grille (`nil` : sans limite) et vies restantes. Une gemme posée au mauvais endroit coûte une vie.
    let maxLives: Int?
    private(set) var livesLeft: Int?
    /// « Continuer » utilisés (vidéo après avoir perdu toutes les vies).
    private(set) var continues: Int
    /// Plus de vies : la grille est bloquée jusqu'à « Continuer » ou « Recommencer ».
    private(set) var failed = false
    /// Compteur pour animer le cœur perdu.
    private(set) var lifeLostToken = 0

    private(set) var solved = false
    private(set) var reward: Reward?
    private(set) var finalSeconds = 0

    private var elapsedBefore: Double
    private var runningSince: Date?
    private weak var app: AppModel?

    init(app: AppModel, kind: PuzzleKind, grid: LumiCore.Grid, saved: SavedGrid?, lives: Int?) {
        self.app = app
        self.kind = kind
        maxLives = lives
        livesLeft = lives.map { max(0, min($0, saved?.livesLeft ?? $0)) }
        continues = saved?.continues ?? 0
        failed = livesLeft == 0
        let marks = saved?.marks.compactMap { Mark(rawValue: $0) }
        board = Board(grid: grid, marks: marks)
        hintsUsed = saved?.hintsUsed ?? 0
        elapsedBefore = saved?.elapsed ?? 0
        runningSince = failed ? nil : Date()
    }

    var palette: Palette { app?.palette ?? Palette(Catalog.theme(Catalog.defaultTheme)) }
    var autoCrosses: Bool { app?.profile.autoCrosses ?? true }
    var hintsLeft: Int { app?.profile.hints ?? 0 }

    // MARK: Chronomètre

    func elapsed(at now: Date = Date()) -> Double {
        elapsedBefore + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    /// L'app passe en arrière-plan : le chronomètre s'arrête et la grille est gardée.
    func pause() {
        guard let since = runningSince else { return }
        elapsedBefore += Date().timeIntervalSince(since)
        runningSince = nil
        persist()
    }

    func resume() {
        guard !solved, !failed, runningSince == nil else { return }
        runningSince = Date()
    }

    // MARK: Gestes

    func tap(_ cell: Int) {
        guard !solved, !failed else { return }
        let before = snapshot()
        let mark = board.tap(cell)
        if mark == .gem, maxLives != nil, board.isMistake(cell) {
            mistake(at: cell)
            return
        }
        switch mark {
        case .cross: app?.sound.play(.cross); app?.haptics.tap()
        case .gem: app?.sound.play(.gem(board.layout.zones[cell])); app?.haptics.gem()
        case .empty: app?.haptics.tap()
        }
        changed(from: before, touched: cell)
    }

    private var stroking = false

    /// Glissé du doigt : croix sur les cases vides traversées (une seule étape d'annulation).
    func stroke(_ cell: Int) {
        guard !solved, !failed else { return }
        if !stroking {
            stroking = true
            board.beginStroke()
        }
        if board.strokeCross(cell) {
            app?.sound.play(.cross)
            app?.haptics.tap()
        }
    }

    func endStroke() {
        guard stroking else { return }
        stroking = false
        clearMessage()
        persist()
    }

    func undo() {
        guard !solved, !failed, board.canUndo else { return }
        board.undo()
        app?.haptics.tap()
        clearMessage()
        persist()
    }

    func clear() {
        guard !solved, !failed else { return }
        board.clear()
        app?.haptics.tap()
        clearMessage()
        persist()
    }

    // MARK: Indices

    enum HintOutcome {
        case shown
        /// Plus d'indice : proposer la pub.
        case needHints
    }

    @discardableResult
    func hint() -> HintOutcome {
        guard !solved, !failed, let app, let hint = board.hint(autoCrosses: autoCrosses) else { return .shown }
        if !hint.isFree {
            guard app.spendHint() else { return .needHints }
            hintsUsed += 1
        }
        let before = snapshot()
        board.apply(hint)
        highlight = hint.cells
        highlightToken += 1
        message = hint.message
        messageIsError = hint.isFree
        app.sound.play(.hint)
        app.haptics.gem()
        changed(from: before, touched: nil, keepMessage: true)
        return .shown
    }

    // MARK: Vies

    /// Gemme au mauvais endroit : une vie en moins, la gemme rougit puis part (la case est barrée).
    private func mistake(at cell: Int) {
        livesLeft = max(0, (livesLeft ?? 0) - 1)
        lifeLostToken += 1
        let left = livesLeft ?? 0
        message = left > 0 ? "Pas ici ! Il te reste \(left) vie\(left > 1 ? "s" : "")." : "Plus de vies…"
        messageIsError = true
        highlight = []
        app?.sound.play(.error)
        app?.haptics.error()
        if left == 0 {
            failed = true
            pause()
        }
        Task {
            try? await Task.sleep(for: .seconds(0.55))
            board.punish(cell)
            persist()
        }
    }

    var canContinue: Bool { continues < Economy.maxContinues }

    /// Après une vidéo : on repart avec une vie.
    func continueAfterAd() {
        guard failed else { return }
        continues += 1
        livesLeft = Economy.continueLives
        failed = false
        clearMessage()
        resume()
        persist()
    }

    /// Recommencer la grille de zéro, toutes les vies rendues (le chronomètre continue).
    func restart() {
        board.restart()
        livesLeft = maxLives
        failed = false
        clearMessage()
        resume()
        persist()
    }

    // MARK: Après chaque changement

    private struct Snapshot {
        var resolved: [Bool]
        var links: [Bool]
    }

    private func snapshot() -> Snapshot { Snapshot(resolved: board.resolvedZones, links: board.links) }

    private func changed(from before: Snapshot, touched cell: Int?, keepMessage: Bool = false) {
        let now = snapshot()
        // Nouvelle zone résolue : éclat de la zone.
        if let zone = now.resolved.indices.first(where: { now.resolved[$0] && !before.resolved[$0] }) {
            flashZone = zone
            flashToken += 1
        }
        // Nouveau rayon entre deux gemmes.
        if let link = now.links.indices.last(where: { now.links[$0] && !before.links[$0] }) {
            app?.sound.play(.link(link))
            app?.haptics.link()
        }
        // Règle enfreinte par la gemme posée.
        if let cell, let found = board.conflict(at: cell) {
            let layout = board.layout
            message = Hint.explain(found.conflict, layout.zones[cell] + 1, layout.zones[found.other] + 1)
            messageIsError = true
            app?.sound.play(.error)
            app?.haptics.error()
        } else if !keepMessage {
            clearMessage()
        }
        if board.isSolved {
            win()
        } else {
            persist()
        }
    }

    private func clearMessage() {
        message = nil
        messageIsError = false
        highlight = []
    }

    private func persist() {
        guard !solved else { return }
        app?.keep(SavedGrid(key: kind.key, marks: board.marks.map(\.rawValue), elapsed: elapsed(), hintsUsed: hintsUsed,
                            livesLeft: livesLeft, continues: continues))
    }

    private func win() {
        pause()
        solved = true
        finalSeconds = max(1, Int(elapsed().rounded()))
        highlight = []
        message = nil
        reward = app?.finish(kind, seconds: finalSeconds, hintsUsed: hintsUsed, continues: continues)
        app?.haptics.success()
        // L'arpège part pendant que le rayon parcourt la chaîne (voir BoardView).
        Task {
            try? await Task.sleep(for: .seconds(Double(board.size) * 0.12))
            app?.sound.play(.win)
        }
    }
}

/// « 2:07 ».
func formatTime(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return "\(total / 60):" + String(format: "%02d", total % 60)
}
