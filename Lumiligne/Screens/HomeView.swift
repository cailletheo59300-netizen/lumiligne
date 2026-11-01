import SwiftUI
import LumiCore

/// Accueil : grille animée, grille du jour (et bonus), chapitre en cours, puis Parcours, Libre, Thèmes, Classements.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showShop = false
    @State private var showSettings = false
    @State private var showLevels = false
    @State private var showFree = false
    @State private var busy = false

    var body: some View {
        let palette = app.palette
        ZStack {
            Backdrop(palette: palette)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    topBar(palette)
                    VStack(spacing: 4) {
                        HeroBoard(palette: palette)
                            .frame(width: 150, height: 150)
                            .padding(.bottom, 6)
                        Text("Lumiligne")
                            .font(Fonts.title(44))
                            .foregroundStyle(palette.text)
                        Text("Relie les gemmes. Ne devine jamais.")
                            .font(Fonts.body(15, .medium))
                            .foregroundStyle(palette.secondary)
                    }
                    .padding(.bottom, 4)
                    DailyCard(busy: $busy)
                    ChapterCard(showLevels: $showLevels)
                    HStack(spacing: 10) {
                        tile(palette, "Parcours") { PathIcon(size: 30, tint: palette.text) } action: { showLevels = true }
                        tile(palette, "Libre") { FreeIcon(size: 30, tint: palette.line) } action: { showFree = true }
                        tile(palette, "Thèmes") { ThemesIcon(size: 30) } action: { showShop = true }
                        tile(palette, "Classements") { TrophyIcon(size: 30) } action: { app.gameCenter.showLeaderboards() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            if busy { LoadingVeil() }
        }
        .sheet(isPresented: $showShop) { ShopView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLevels) { LevelsView() }
        .sheet(isPresented: $showFree) { FreePlayView().presentationDetents([.medium, .large]) }
    }

    private func topBar(_ palette: Palette) -> some View {
        HStack(spacing: 10) {
            Chip(palette: palette, text: "\(app.profile.hints)") { HintIcon(size: 18) }
                .accessibilityLabel("\(app.profile.hints) indices")
            let streak = app.profile.currentStreak(today: app.today)
            if streak > 0 {
                Chip(palette: palette, text: "\(streak)") { FlameIcon(size: 18) }
                    .accessibilityLabel("Série de \(streak) jours")
            }
            Spacer()
            Button {
                app.haptics.tap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.text)
                    .frame(width: 42, height: 42)
                    .card(palette, radius: 21)
            }
            .accessibilityLabel("Réglages")
        }
        .padding(.top, 8)
    }

    private func tile<Icon: View>(_ palette: Palette, _ title: String, @ViewBuilder icon: () -> Icon,
                                  action: @escaping () -> Void) -> some View {
        Button {
            app.haptics.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                icon().frame(height: 32)
                Text(title)
                    .font(Fonts.body(12, .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .card(palette, radius: 18)
        }
        .buttonStyle(PressStyle())
    }
}

/// Léger enfoncement au toucher, pour les cartes cliquables.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Carte du chapitre en cours : nom, avancement, prochain niveau.
private struct ChapterCard: View {
    @Environment(AppModel.self) private var app
    @Binding var showLevels: Bool

    var body: some View {
        let palette = app.palette
        let level = app.profile.nextLevel
        let chapter = Chapters.chapter(of: level)
        let done = Chapters.position(of: level)
        let size = Puzzles.levelSize(level)
        let started = app.profile.saved(PuzzleKind.level(level).key) != nil
        VStack(alignment: .leading, spacing: 12) {
            Button {
                app.haptics.tap()
                showLevels = true
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    ChapterEmblem(chapter: chapter, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CHAPITRE \(chapter)")
                            .font(Fonts.body(12, .heavy))
                            .tracking(1.4)
                            .foregroundStyle(palette.secondary)
                        Text(Chapters.name(chapter))
                            .font(Fonts.title(24))
                            .foregroundStyle(palette.text)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        MedalIcon(size: 15)
                        Text("\(app.profile.medals(chapter: chapter))").font(Fonts.number(14))
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(palette.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ProgressDots(done: done, total: Chapters.levelsPerChapter, palette: palette)

            Button {
                app.haptics.tap()
                app.playNextLevel()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(started ? "Reprendre" : (Chapters.isChallenge(level) ? "Défi du chapitre" : "Jouer"))
                            .font(Fonts.body(13, .semibold)).opacity(0.75)
                        Text("Niveau \(level)").font(Fonts.title(22))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(size) × \(size)").font(Fonts.number(15))
                        DifficultyDots(difficulty: Puzzles.levelDifficulty(level), color: palette.backgroundTop)
                    }
                    Image(systemName: "play.fill").font(.system(size: 18, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(palette.beam))
                        .foregroundStyle(Color.black.opacity(0.8))
                }
                .foregroundStyle(palette.backgroundTop)
                .padding(.leading, 18)
                .padding(.trailing, 10)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.text))
            }
            .buttonStyle(PressStyle())
        }
        .padding(16)
        .card(palette, radius: 22)
    }
}

/// Avancement d'un chapitre : 20 petits losanges, allumés pour les niveaux finis.
struct ProgressDots: View {
    let done: Int
    let total: Int
    let palette: Palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<total, id: \.self) { i in
                DiamondShape()
                    .fill(i < done ? palette.beam : palette.text.opacity(0.12))
                    .frame(width: i == total - 1 ? 11 : 8, height: i == total - 1 ? 11 : 8)
                    .shadow(color: i < done ? palette.beam.opacity(0.6) : .clear, radius: 3)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) niveaux sur \(total)")
    }
}

/// Difficulté en 3 petits losanges.
struct DifficultyDots: View {
    let difficulty: Difficulty
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                DiamondShape()
                    .fill(i <= difficulty.rawValue ? color : color.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel(difficulty.name)
    }
}

/// Carte de la grille du jour : à faire / finie (temps), compte à rebours, grille bonus.
private struct DailyCard: View {
    @Environment(AppModel.self) private var app
    @Binding var busy: Bool

    var body: some View {
        let palette = app.palette
        let day = app.today
        let done = app.profile.dailyDone(today: day)
        let plan = Puzzles.plan(.daily(day))
        VStack(spacing: 12) {
            Button {
                app.haptics.tap()
                app.playDaily()
            } label: {
                HStack(spacing: 14) {
                    CalendarBadge(day: Int(day.suffix(2)) ?? 1, palette: palette)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Grille du jour").font(Fonts.body(18, .bold)).foregroundStyle(palette.text)
                        Text(subtitle(done: done, plan: plan))
                            .font(Fonts.body(13, .medium))
                            .foregroundStyle(palette.secondary)
                    }
                    Spacer()
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(palette.success))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.8))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(palette.beam))
                            .shadow(color: palette.beam.opacity(0.6), radius: 8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())

            if app.profile.bonusAvailable(today: day) {
                bonusButton(palette, title: "Jouer la grille bonus", ad: false)
            } else if app.profile.canUnlockBonus(today: day) {
                bonusButton(palette, title: "Grille bonus", ad: true)
            }
        }
        .padding(16)
        .card(palette, radius: 22, border: palette.beam.opacity(0.6), borderWidth: 1.5)
    }

    private func bonusButton(_ palette: Palette, title: String, ad: Bool) -> some View {
        Button {
            app.haptics.tap()
            if !ad {
                app.playBonus()
                return
            }
            Task {
                busy = true
                let unlocked = await app.unlockBonus()
                busy = false
                if unlocked { app.playBonus() }
            }
        } label: {
            HStack(spacing: 8) {
                if ad {
                    Image(systemName: "play.rectangle.fill")
                } else {
                    SparkleShape().fill(palette.beam).frame(width: 16, height: 16)
                }
                Text(title)
                Spacer()
                Text("8 × 8").font(Fonts.number(13)).opacity(0.7)
                DifficultyDots(difficulty: .hard, color: palette.text)
            }
            .font(Fonts.body(15, .bold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.beam.opacity(0.18)))
        }
        .buttonStyle(PressStyle())
    }

    private func subtitle(done: Bool, plan: Puzzles.Plan) -> String {
        if done, let time = app.profile.dailyTime {
            return "Finie en \(formatTime(Double(time))) · prochaine dans \(Self.countdown())"
        }
        let started = app.profile.saved(PuzzleKind.daily(app.today).key) != nil
        return "\(started ? "À reprendre" : "La même pour tout le monde") · \(plan.size) × \(plan.size)"
    }

    static func countdown() -> String {
        let seconds = Int(DayKey.secondsUntilNextDay())
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes))" : "\(minutes) min"
    }
}

/// Petit calendrier avec le numéro du jour.
private struct CalendarBadge: View {
    let day: Int
    let palette: Palette

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(palette.beam)
                .frame(height: 12)
            Text("\(day)")
                .font(Fonts.number(20, .heavy))
                .foregroundStyle(Color(hex: "#1F2333"))
                .frame(maxHeight: .infinity)
        }
        .frame(width: 44, height: 48)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(palette.line.opacity(0.35), lineWidth: 1))
        .shadow(color: palette.shadow, radius: 4, y: 2)
    }
}

/// Grille animée de l'accueil : le rayon se dessine de gemme en gemme, puis tout recommence.
struct HeroBoard: View {
    let palette: Palette

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5) / 5
            let progress = min(1, max(0, (t - 0.08) / 0.5))
            let fade = t > 0.88 ? max(0, 1 - (t - 0.88) / 0.12) : 1
            ThemePreview(palette: palette, progress: progress, beamOpacity: fade, transparent: true)
        }
        .rotationEffect(.degrees(-4))
        .shadow(color: palette.shadow, radius: 12, y: 6)
        .accessibilityHidden(true)
    }
}
