import SwiftUI
import LumiCore

/// Le parcours : chapitres de 20 niveaux. Niveaux finis (rejouables, avec meilleur temps et médaille « sans indice »),
/// prochain niveau (qui brille), niveaux à venir (verrouillés). On voit aussi le chapitre suivant.
struct LevelsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let palette = app.palette
        let current = Chapters.chapter(of: app.profile.nextLevel)
        NavigationStack {
            ZStack {
                Backdrop(palette: palette)
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(1...(current + 1), id: \.self) { chapter in
                                ChapterSection(chapter: chapter, locked: chapter > current) { level in
                                    dismiss()
                                    app.playLevel(level)
                                }
                                .id(chapter)
                            }
                            Text("Les chapitres continuent à l'infini, avec toutes les tailles de grille mélangées.")
                                .font(Fonts.body(13, .medium))
                                .foregroundStyle(palette.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(20)
                    }
                    .onAppear { scroll.scrollTo(current, anchor: .top) }
                }
            }
            .navigationTitle("Parcours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Fonts.body(17, .bold))
                }
            }
        }
    }
}

/// Un chapitre : en-tête (nom, médailles, avancement) et ses 20 niveaux.
private struct ChapterSection: View {
    @Environment(AppModel.self) private var app
    let chapter: Int
    let locked: Bool
    let play: (Int) -> Void

    var body: some View {
        let palette = app.palette
        let levels = Array(Chapters.levels(of: chapter))
        let done = levels.filter { $0 <= app.profile.levelsDone }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ChapterEmblem(chapter: chapter, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAPITRE \(chapter)")
                        .font(Fonts.body(12, .heavy))
                        .tracking(1.4)
                        .foregroundStyle(palette.secondary)
                    Text(Chapters.name(chapter)).font(Fonts.title(24)).foregroundStyle(palette.text)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(palette.secondary)
                } else {
                    HStack(spacing: 5) {
                        MedalIcon(size: 16)
                        Text("\(app.profile.medals(chapter: chapter))").font(Fonts.number(14))
                        Text("· \(done)/\(Chapters.levelsPerChapter)").font(Fonts.number(14))
                    }
                    .foregroundStyle(palette.secondary)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                ForEach(levels, id: \.self) { level in
                    LevelPill(level: level, palette: palette) { play(level) }
                }
            }
            HStack(spacing: 6) {
                Text("Fin du chapitre :").foregroundStyle(palette.secondary)
                HintIcon(size: 16)
                Text("+\(Economy.chapterReward)").foregroundStyle(palette.text)
                if let theme = Catalog.themes.first(where: { $0.price == .level(levels[levels.count - 1]) }) {
                    ThemesIcon(size: 16, colors: [Color(hex: theme.zones[0]), Color(hex: theme.zones[1]), Color(hex: theme.zones[2])])
                    Text("thème \(theme.name)").foregroundStyle(palette.text)
                }
            }
            .font(Fonts.body(13, .semibold))
        }
        .padding(16)
        .card(palette, radius: 22)
        .opacity(locked ? 0.7 : 1)
    }
}

/// Une pastille de niveau : losange de couleur (fini), lumineux (prochain) ou verrouillé.
private struct LevelPill: View {
    @Environment(AppModel.self) private var app
    let level: Int
    let palette: Palette
    let action: () -> Void

    var body: some View {
        let next = level == app.profile.nextLevel
        let done = level <= app.profile.levelsDone
        let stat = app.profile.stat(level)
        let size = Puzzles.levelSize(level)
        let challenge = Chapters.isChallenge(level)
        Button {
            app.haptics.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(done ? palette.zone(level % 9) : (next ? palette.beam.opacity(0.22) : palette.text.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(next ? palette.beam : (done ? palette.line.opacity(0.7) : palette.stroke),
                                    lineWidth: next ? 2.5 : (done ? 1.5 : 1)))
                        .shadow(color: next ? palette.beam.opacity(0.7) : .clear, radius: 8)
                    if done || next {
                        Text("\(level)")
                            .font(Fonts.number(level >= 100 ? 14 : 17, .heavy))
                            .foregroundStyle(done ? Color(hex: "#1F2333") : palette.text)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.secondary.opacity(0.7))
                    }
                }
                .frame(height: 52)
                .overlay(alignment: .topTrailing) {
                    if stat?.noHint == true {
                        MedalIcon(size: 15).offset(x: 5, y: -5)
                    } else if challenge {
                        DiamondShape().fill(IconInk.gold)
                            .overlay(DiamondShape().stroke(IconInk.outline, lineWidth: 0.8))
                            .frame(width: 13, height: 13)
                            .offset(x: 4, y: -4)
                    }
                }
                Text(stat.map { formatTime(Double($0.bestTime)) } ?? "\(size)×\(size)")
                    .font(Fonts.number(10, .semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PressStyle())
        .disabled(!(done || next))
        .accessibilityLabel(accessibility(done: done, next: next, stat: stat, size: size))
    }

    private func accessibility(done: Bool, next: Bool, stat: LevelStat?, size: Int) -> String {
        var text = "Niveau \(level), \(size) sur \(size)"
        if done, let stat { text += ", fini en \(formatTime(Double(stat.bestTime)))" + (stat.noHint ? ", sans indice" : "") }
        if next { text += ", à jouer" }
        if !done && !next { text += ", verrouillé" }
        return text
    }
}

/// Mode Libre : choisir la taille et la difficulté, puis jouer autant de grilles qu'on veut (hors parcours).
struct FreePlayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumiligne.free.size") private var size = 6
    @AppStorage("lumiligne.free.difficulty") private var difficultyRaw = Difficulty.medium.rawValue

    private var difficulty: Difficulty { Difficulty(rawValue: difficultyRaw) ?? .medium }

    var body: some View {
        let palette = app.palette
        let kind = app.profile.freeKind(size: size, difficulty: difficulty)
        let started = app.profile.saved(kind.key) != nil
        NavigationStack {
            ZStack {
                Backdrop(palette: palette)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Choisis ta grille. Elle ne compte pas pour le parcours : joue autant que tu veux.")
                            .font(Fonts.body(15, .medium))
                            .foregroundStyle(palette.secondary)

                        section(palette, "Taille") {
                            HStack(spacing: 8) {
                                ForEach(Puzzles.freeSizes, id: \.self) { value in
                                    choice(palette, selected: value == size) {
                                        VStack(spacing: 4) {
                                            MiniGridGlyph(size: value, color: value == size ? Color.black.opacity(0.75) : palette.text)
                                                .frame(width: 22, height: 22)
                                            Text("\(value)×\(value)").font(Fonts.number(13))
                                        }
                                    } action: { size = value }
                                }
                            }
                        }

                        section(palette, "Vies") {
                            HStack(spacing: 8) {
                                ForEach(Puzzles.freeLivesChoices, id: \.self) { value in
                                    choice(palette, selected: value == app.profile.freeLives) {
                                        VStack(spacing: 4) {
                                            if value == 0 {
                                                Image(systemName: "infinity").font(.system(size: 18, weight: .bold)).frame(height: 20)
                                            } else {
                                                HeartIcon(size: 20)
                                            }
                                            Text(value == 0 ? "Sans" : "\(value)").font(Fonts.number(13))
                                        }
                                    } action: { app.update { $0.freeLives = value } }
                                }
                            }
                        }

                        section(palette, "Difficulté") {
                            HStack(spacing: 8) {
                                ForEach(Difficulty.allCases, id: \.self) { value in
                                    choice(palette, selected: value == difficulty) {
                                        VStack(spacing: 6) {
                                            DifficultyDots(difficulty: value, color: value == difficulty ? Color.black.opacity(0.75) : palette.text)
                                            Text(value.name).font(Fonts.body(14, .bold))
                                        }
                                    } action: { difficultyRaw = value.rawValue }
                                }
                            }
                        }

                        Button {
                            app.haptics.tap()
                            dismiss()
                            app.playFree(size: size, difficulty: difficulty)
                        } label: {
                            Label(started ? "Reprendre la grille" : "Jouer", systemImage: "play.fill")
                        }
                        .buttonStyle(PillButtonStyle(palette: palette, tint: palette.beam))

                        if let solved = solvedCount, solved > 0 {
                            Text("\(solved) grille\(solved > 1 ? "s" : "") finie\(solved > 1 ? "s" : "") dans cette série")
                                .font(Fonts.body(13, .medium))
                                .foregroundStyle(palette.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Libre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Fonts.body(17, .bold))
                }
            }
        }
    }

    private var solvedCount: Int? {
        if case .free(_, _, let number) = app.profile.freeKind(size: size, difficulty: difficulty) { return number - 1 }
        return nil
    }

    private func section<Content: View>(_ palette: Palette, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(Fonts.body(12, .heavy))
                .tracking(1.4)
                .foregroundStyle(palette.secondary)
            content()
        }
    }

    private func choice<Content: View>(_ palette: Palette, selected: Bool, @ViewBuilder label: () -> Content,
                                     action: @escaping () -> Void) -> some View {
        Button {
            app.haptics.tap()
            action()
        } label: {
            label()
                .foregroundStyle(selected ? Color.black.opacity(0.8) : palette.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selected ? palette.beam : palette.card))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selected ? .clear : palette.stroke, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// Petite grille de N × N traits (pour choisir la taille).
private struct MiniGridGlyph: View {
    let size: Int
    let color: Color

    var body: some View {
        Canvas { context, s in
            let c = s.width / CGFloat(size)
            var path = Path()
            for k in 0...size {
                let p = CGFloat(k) * c
                path.move(to: CGPoint(x: p, y: 0)); path.addLine(to: CGPoint(x: p, y: s.height))
                path.move(to: CGPoint(x: 0, y: p)); path.addLine(to: CGPoint(x: s.width, y: p))
            }
            context.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 1)
        }
    }
}

/// Emblème d'un chapitre : une gemme à sa couleur, avec son numéro.
struct ChapterEmblem: View {
    let chapter: Int
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            FacetedGem(colors: [.white, Color(hex: Chapters.color(chapter)), Color(hex: Chapters.color(chapter))], size: size)
            Text("\(chapter)")
                .font(Fonts.number(size * (chapter >= 10 ? 0.26 : 0.32), .heavy))
                .foregroundStyle(Color(hex: "#1F2333"))
        }
        .accessibilityHidden(true)
    }
}
