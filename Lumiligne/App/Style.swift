import SwiftUI
import UIKit
import LumiCore

/// Couleurs de l'interface, tirées du thème choisi (`Catalog`). Clair et doux par défaut (Aube).
struct Palette {
    let skin: ThemeSkin

    init(_ skin: ThemeSkin) { self.skin = skin }

    var dark: Bool { skin.dark }
    var backgroundTop: Color { Color(hex: skin.background[0]) }
    var backgroundBottom: Color { Color(hex: skin.background[1]) }
    var background: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }
    var surface: Color { Color(hex: skin.surface) }
    var text: Color { Color(hex: skin.text) }
    var secondary: Color { text.opacity(0.62) }
    var line: Color { Color(hex: skin.line) }
    var beam: Color { Color(hex: skin.beam) }
    var stroke: Color { text.opacity(dark ? 0.16 : 0.12) }
    var card: Color { dark ? Color.white.opacity(0.07) : surface }
    var shadow: Color { dark ? Color.black.opacity(0.35) : Color(hex: "#2A2F45").opacity(0.08) }
    var error: Color { Color(hex: dark ? "#FF6B6B" : "#D93A3A") }
    var success: Color { Color(hex: dark ? "#3FD19A" : "#1F9D6B") }

    func zone(_ index: Int) -> Color { Color(hex: skin.zones[index % skin.zones.count]) }

    /// Symbole de chaque zone (option daltonisme), en plus de la couleur et du numéro.
    static let symbols = ["circle.fill", "triangle.fill", "square.fill", "diamond.fill", "star.fill", "heart.fill",
                          "hexagon.fill", "moon.fill", "plus"]
    static func symbol(_ zone: Int) -> String { symbols[zone % symbols.count] }
}

/// Polices : titres en serif (New York), texte en SF Pro.
enum Fonts {
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight) }
    static func number(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

extension UIColor {
    /// « #RRGGBB ».
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

/// Bouton principal : plein (couleur du texte du thème) ou discret.
struct PillButtonStyle: ButtonStyle {
    let palette: Palette
    var filled = true
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let color = tint ?? palette.text
        return configuration.label
            .font(Fonts.body(18, .bold))
            .foregroundStyle(filled ? (tint == nil ? palette.backgroundTop : Color.black.opacity(0.85)) : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(filled ? color : palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(filled ? .clear : palette.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Petite pastille (indices, série, temps) avec son icône dessinée.
struct Chip<Icon: View>: View {
    let palette: Palette
    let text: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(text).font(Fonts.number(16)).foregroundStyle(palette.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(palette.card))
        .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
        .shadow(color: palette.shadow, radius: 6, y: 2)
    }
}

/// Fond d'une carte : surface du thème, bord fin, ombre douce (thèmes clairs) ou reflet (thèmes sombres).
struct CardBackground: ViewModifier {
    let palette: Palette
    var radius: CGFloat = 20
    var border: Color?
    var borderWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(palette.card)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(palette.dark ? 0.06 : 0), .clear],
                                             startPoint: .top, endPoint: .bottom)))
                    .shadow(color: palette.shadow, radius: 14, y: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(border ?? palette.stroke, lineWidth: borderWidth))
    }
}

extension View {
    func card(_ palette: Palette, radius: CGFloat = 20, border: Color? = nil, borderWidth: CGFloat = 1) -> some View {
        modifier(CardBackground(palette: palette, radius: radius, border: border, borderWidth: borderWidth))
    }
}

/// Fond des écrans : dégradé du thème, trame de points très discrète et un halo de lumière en haut.
struct Backdrop: View {
    let palette: Palette

    var body: some View {
        ZStack {
            palette.background
            RadialGradient(colors: [palette.beam.opacity(palette.dark ? 0.18 : 0.16), .clear],
                           center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 420)
            Canvas { context, size in
                let step: CGFloat = 22
                let dot = palette.text.opacity(palette.dark ? 0.07 : 0.06)
                var y: CGFloat = step / 2
                while y < size.height {
                    var x: CGFloat = step / 2
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(dot))
                        x += step
                    }
                    y += step
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Voile d'attente (pub ou achat en cours, grille en préparation).
struct LoadingVeil: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView().controlSize(.large).tint(.white)
        }
    }
}

/// Une gemme : losange facetté (couleur de sa zone), table claire, reflet, et son numéro.
struct GemView: View {
    let palette: Palette
    let color: Color
    let number: Int
    var size: CGFloat
    var lit = false
    var bad = false

    var body: some View {
        ZStack {
            Canvas { context, s in
                let rect = CGRect(origin: .zero, size: s).insetBy(dx: s.width * 0.14, dy: s.height * 0.14)
                let c = CGPoint(x: rect.midX, y: rect.midY)
                let top = CGPoint(x: rect.midX, y: rect.minY), right = CGPoint(x: rect.maxX, y: rect.midY)
                let bottom = CGPoint(x: rect.midX, y: rect.maxY), left = CGPoint(x: rect.minX, y: rect.midY)
                let outer = DiamondShape().path(in: rect)
                context.fill(outer, with: .linearGradient(Gradient(colors: [.white, color, color]),
                                                          startPoint: top, endPoint: bottom))
                // Facettes : côté droit dans l'ombre, côté gauche éclairé.
                var shade = Path()
                shade.move(to: top); shade.addLine(to: right); shade.addLine(to: bottom); shade.addLine(to: c); shade.closeSubpath()
                context.fill(shade, with: .color(.black.opacity(0.13)))
                var light = Path()
                light.move(to: top); light.addLine(to: c); light.addLine(to: left); light.closeSubpath()
                context.fill(light, with: .color(.white.opacity(0.35)))
                let table = DiamondShape().path(in: CGRect(x: c.x - rect.width * 0.24, y: c.y - rect.height * 0.24,
                                                           width: rect.width * 0.48, height: rect.height * 0.48))
                context.fill(table, with: .color(.white.opacity(0.78)))
                context.stroke(outer, with: .color(bad ? palette.error : palette.line),
                               style: StrokeStyle(lineWidth: max(1.8, s.width * 0.065), lineJoin: .round))
            }
            .shadow(color: lit ? palette.beam.opacity(0.95) : .black.opacity(0.18), radius: lit ? size * 0.22 : size * 0.05,
                    y: lit ? 0 : size * 0.03)
            Text("\(number)")
                .font(Fonts.number(size * 0.26, .heavy))
                .foregroundStyle(bad ? palette.error : Color(hex: "#1F2333"))
        }
        .frame(width: size, height: size)
    }
}
