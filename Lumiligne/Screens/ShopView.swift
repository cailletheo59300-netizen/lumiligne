import SwiftUI
import LumiCore

/// Boutique : thèmes (gratuits, débloqués par les niveaux, ou premium) et offres (pack de départ, Sans pub, indices).
/// Tout s'achète directement, sans hasard.
struct ShopView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab

    enum Tab: String, CaseIterable, Identifiable {
        case themes = "Thèmes"
        case offers = "Offres"
        var id: String { rawValue }
    }

    init(startOnOffers: Bool = false) {
        _tab = State(initialValue: startOnOffers ? .offers : .themes)
    }

    var body: some View {
        let palette = app.palette
        NavigationStack {
            ZStack {
                Backdrop(palette: palette)
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Rayon", selection: $tab) {
                            ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .themes:
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(Catalog.themes) { ThemeCard(theme: $0) }
                            }
                        case .offers:
                            OffersList()
                        }

                        if let message = app.store.message {
                            Text(message)
                                .font(Fonts.body(14))
                                .foregroundStyle(palette.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                }
                if app.store.busy { LoadingVeil() }
            }
            .navigationTitle("Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Chip(palette: palette, text: "\(app.profile.hints)") { HintIcon(size: 18) }.fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Fonts.body(17, .bold))
                }
            }
        }
        .task { await app.store.loadProducts() }
    }
}

/// Un thème : aperçu réel (petite grille avec ses couleurs), nom, et bouton.
private struct ThemeCard: View {
    @Environment(AppModel.self) private var app
    let theme: ThemeSkin

    private var owned: Bool { app.profile.owns(theme) }
    private var selected: Bool { app.profile.theme == theme.id }

    var body: some View {
        let palette = app.palette
        VStack(spacing: 10) {
            ThemePreview(palette: Palette(theme))
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if case .store = theme.price {
                        Text("PREMIUM")
                            .font(Fonts.body(10, .heavy))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: theme.beam)))
                            .padding(6)
                    }
                }
            Text(theme.name).font(Fonts.body(16, .bold)).foregroundStyle(palette.text)
            action(palette)
        }
        .padding(12)
        .card(palette, radius: 18, border: selected ? palette.beam : nil, borderWidth: selected ? 2.5 : 1)
    }

    @ViewBuilder
    private func action(_ palette: Palette) -> some View {
        if selected {
            label("Choisi", icon: "checkmark", color: palette.text, filled: false, palette: palette)
        } else if owned {
            Button { app.select(theme) } label: { label("Choisir", color: palette.text, filled: true, palette: palette) }
        } else {
            switch theme.price {
            case .free:
                EmptyView()
            case .level(let number):
                label("Niveau \(number)", icon: "lock.fill", color: palette.secondary, filled: false, palette: palette)
            case .store(let product):
                Button {
                    Task {
                        if await app.store.purchase(product) {
                            app.haptics.success()
                            app.select(theme)
                        }
                    }
                } label: {
                    label(app.store.price(product) ?? "…", color: palette.beam, filled: true, palette: palette)
                }
            }
        }
    }

    private func label(_ text: String, icon: String? = nil, color: Color, filled: Bool, palette: Palette) -> some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon) }
            Text(text).monospacedDigit()
        }
        .font(Fonts.body(15, .bold))
        .foregroundStyle(filled ? (color == palette.text ? palette.backgroundTop : Color.black.opacity(0.85)) : color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Capsule().fill(filled ? color : color.opacity(0.1)))
    }
}

/// Petite grille d'exemple dessinée avec les couleurs d'un thème (zones, gemmes, rayon).
/// `progress` (0…1) dessine le rayon progressivement, les gemmes apparaissant à son passage (grille animée de l'accueil).
struct ThemePreview: View {
    let palette: Palette
    var progress: Double = 1
    var beamOpacity: Double = 1
    /// Sans fond (posée directement sur l'écran).
    var transparent = false

    /// Grille 5 × 5 d'exemple et sa solution (gemmes alignées deux à deux, qui ne se touchent pas).
    private static let zones = [0, 0, 1, 1, 1,
                                0, 4, 4, 1, 1,
                                0, 4, 4, 2, 1,
                                3, 3, 2, 2, 2,
                                3, 3, 3, 2, 2]
    private static let gems = [0, 3, 23, 21, 11]

    var body: some View {
        ZStack {
            if !transparent { palette.background }
            Canvas { context, size in
                let side = min(size.width, size.height) - (transparent ? 4 : 16)
                let c = side / 5
                let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
                func rect(_ i: Int) -> CGRect {
                    CGRect(x: origin.x + CGFloat(i % 5) * c, y: origin.y + CGFloat(i / 5) * c, width: c, height: c)
                }
                let frame = Path(roundedRect: CGRect(origin: origin, size: CGSize(width: side, height: side)), cornerRadius: c * 0.25)
                var clipped = context
                clipped.clip(to: frame)
                for i in 0..<25 { clipped.fill(Path(rect(i)), with: .color(palette.zone(Self.zones[i]))) }
                var thin = Path()
                for k in 1..<5 {
                    let p = CGFloat(k) * c
                    thin.move(to: CGPoint(x: origin.x + p, y: origin.y)); thin.addLine(to: CGPoint(x: origin.x + p, y: origin.y + side))
                    thin.move(to: CGPoint(x: origin.x, y: origin.y + p)); thin.addLine(to: CGPoint(x: origin.x + side, y: origin.y + p))
                }
                clipped.stroke(thin, with: .color(palette.line.opacity(0.18)), lineWidth: 0.8)
                var borders = Path()
                for i in 0..<25 {
                    let r = rect(i)
                    if i % 5 < 4, Self.zones[i] != Self.zones[i + 1] {
                        borders.move(to: CGPoint(x: r.maxX, y: r.minY)); borders.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                    }
                    if i / 5 < 4, Self.zones[i] != Self.zones[i + 5] {
                        borders.move(to: CGPoint(x: r.minX, y: r.maxY)); borders.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                    }
                }
                clipped.stroke(borders, with: .color(palette.line), style: StrokeStyle(lineWidth: max(1.5, c * 0.07), lineCap: .round))
                context.stroke(frame, with: .color(palette.line), lineWidth: max(2, c * 0.09))

                let points = Self.gems.map { CGPoint(x: rect($0).midX, y: rect($0).midY) }
                var beam = Path()
                for (k, p) in points.enumerated() { if k == 0 { beam.move(to: p) } else { beam.addLine(to: p) } }
                let drawn = beam.trimmedPath(from: 0, to: progress)
                var glow = context
                glow.addFilter(.blur(radius: c * 0.2))
                glow.stroke(drawn, with: .color(palette.beam.opacity(beamOpacity)), style: StrokeStyle(lineWidth: c * 0.28, lineCap: .round, lineJoin: .round))
                context.stroke(drawn, with: .color(palette.beam.opacity(beamOpacity)), style: StrokeStyle(lineWidth: c * 0.12, lineCap: .round, lineJoin: .round))
                for (k, cell) in Self.gems.enumerated() {
                    // La gemme apparaît quand le rayon l'atteint.
                    let reached = Double(k) / Double(Self.gems.count - 1)
                    guard progress >= reached - 0.001 else { continue }
                    let r = rect(cell).insetBy(dx: c * 0.18, dy: c * 0.18)
                    let gem = DiamondShape().path(in: r)
                    context.fill(gem, with: .linearGradient(Gradient(colors: [.white, palette.zone(Self.zones[cell])]),
                                                            startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY)))
                    let table = DiamondShape().path(in: r.insetBy(dx: r.width * 0.28, dy: r.height * 0.28))
                    context.fill(table, with: .color(.white.opacity(0.8)))
                    context.stroke(gem, with: .color(palette.line), lineWidth: max(1.2, c * 0.06))
                }
            }
        }
    }
}

/// Offres en euros : pack de départ (mis en avant), Sans pub, packs d'indices.
private struct OffersList: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let palette = app.palette
        VStack(spacing: 14) {
            if !app.profile.noAds {
                starterCard(palette)
                offerRow(palette, product: .noAds, title: "Sans pub",
                         detail: "Plus aucune pub entre les grilles. Pour toujours.")
            } else {
                Label("Sans pub : activé. Merci !", systemImage: "checkmark.seal.fill")
                    .font(Fonts.body(16, .bold))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .card(palette, radius: 18)
            }

            Text("INDICES")
                .font(Fonts.body(13, .heavy))
                .tracking(1.5)
                .foregroundStyle(palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            HStack(spacing: 10) {
                hintsCard(palette, .hintsSmall, bonus: nil)
                hintsCard(palette, .hintsMedium, bonus: "Populaire")
                hintsCard(palette, .hintsLarge, bonus: "Meilleur prix")
            }
            Text("Tu gagnes aussi des indices en jouant : grille du jour, série de 7 jours, tous les 5 niveaux, ou avec une pub.")
                .font(Fonts.body(13, .medium))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)

            Button("Restaurer les achats") {
                Task { await app.store.restore() }
            }
            .font(Fonts.body(15))
            .foregroundStyle(palette.secondary)
            .padding(.top, 6)
        }
    }

    private func starterCard(_ palette: Palette) -> some View {
        Button {
            Task { if await app.store.purchase(.starter) { app.haptics.success() } }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pack de départ").font(Fonts.title(24)).foregroundStyle(palette.text)
                        Text("Sans pub + 30 indices + 2 thèmes premium")
                            .font(Fonts.body(13, .medium))
                            .foregroundStyle(palette.secondary)
                    }
                    Spacer(minLength: 0)
                    ChestIcon(size: 58)
                }
                HStack(spacing: 8) {
                    ForEach(["theme.neon", "theme.aurora"], id: \.self) { id in
                        VStack(spacing: 4) {
                            ThemePreview(palette: Palette(Catalog.theme(id)))
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(Catalog.theme(id).name).font(Fonts.body(12, .bold)).foregroundStyle(palette.text)
                        }
                    }
                }
                HStack {
                    Label("Une seule fois, pour toujours", systemImage: "checkmark.circle.fill")
                        .font(Fonts.body(13, .semibold))
                        .foregroundStyle(palette.text)
                    Spacer()
                    priceTag(app.store.price(.starter), palette: palette)
                }
            }
            .padding(16)
            .card(palette, radius: 22, border: palette.beam, borderWidth: 2)
        }
        .buttonStyle(.plain)
    }

    private func offerRow(_ palette: Palette, product: StoreProduct, title: String, detail: String) -> some View {
        Button {
            Task { if await app.store.purchase(product) { app.haptics.success() } }
        } label: {
            HStack(spacing: 14) {
                NoAdsIcon(size: 40, tint: palette.text)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Fonts.body(18, .bold)).foregroundStyle(palette.text)
                    Text(detail).font(Fonts.body(13, .medium)).foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                priceTag(app.store.price(product), palette: palette)
            }
            .padding(16)
            .card(palette, radius: 20)
        }
        .buttonStyle(.plain)
    }

    private func hintsCard(_ palette: Palette, _ product: StoreProduct, bonus: String?) -> some View {
        Button {
            Task { if await app.store.purchase(product) { app.haptics.success() } }
        } label: {
            VStack(spacing: 8) {
                HintPile(count: product == .hintsSmall ? 1 : (product == .hintsMedium ? 2 : 3))
                    .frame(height: 40)
                Text("\(product.hints)").font(Fonts.number(22, .heavy)).foregroundStyle(palette.text)
                Text("indices").font(Fonts.body(12, .medium)).foregroundStyle(palette.secondary)
                priceTag(app.store.price(product), palette: palette)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .card(palette, radius: 18, border: bonus != nil ? palette.beam.opacity(0.7) : nil, borderWidth: bonus != nil ? 1.5 : 1)
            .overlay(alignment: .top) {
                if let bonus {
                    Text(bonus)
                        .font(Fonts.body(11, .heavy))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(palette.beam))
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func priceTag(_ price: String?, palette: Palette) -> some View {
        Text(price ?? "…")
            .font(Fonts.body(15, .bold))
            .foregroundStyle(.black.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(palette.beam))
    }
}

/// Tas d'éclats d'indice : 1, 2 ou 3 gemmes selon la taille du pack.
private struct HintPile: View {
    let count: Int

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let offsets: [(CGFloat, CGFloat)] = count == 1 ? [(0, 0)] : (count == 2 ? [(-9, 4), (9, -2)] : [(-13, 6), (13, 6), (0, -6)])
                FacetedGem(size: count == 1 ? 34 : 28)
                    .offset(x: offsets[i].0, y: offsets[i].1)
            }
            SparkleShape().fill(IconInk.cream)
                .overlay(SparkleShape().stroke(IconInk.outline, lineWidth: 0.8))
                .frame(width: 13, height: 13)
                .offset(x: 16, y: -14)
        }
    }
}
