import SwiftUI

// Icônes propres à Lumiligne, toutes dessinées par le code dans le même langage que le jeu : gemmes facettées,
// rayon doré, contours nets. Chaque icône prend une taille en points ; aucune image à produire.

/// Couleurs fixes des icônes (lisibles sur fond clair comme sombre).
enum IconInk {
    static let gold = Color(hex: "#FFC93D")
    static let amber = Color(hex: "#F28C1B")
    static let cream = Color(hex: "#FFF4CF")
    static let outline = Color(hex: "#3A2A12")
    static let violet = Color(hex: "#7B5CFF")
    static let plum = Color(hex: "#3D2A7A")
}

/// Losange (gemme vue de face) inscrit dans `rect`.
struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Étoile à 4 branches (scintillement).
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.22
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        path.closeSubpath()
        return path
    }
}

/// Gemme facettée : dégradé, table claire, facettes, contour.
struct FacetedGem: View {
    var colors: [Color] = [IconInk.cream, IconInk.gold, IconInk.amber]
    var outline: Color = IconInk.outline
    var size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: canvasSize.width * 0.06, dy: canvasSize.height * 0.06)
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let top = CGPoint(x: rect.midX, y: rect.minY), right = CGPoint(x: rect.maxX, y: rect.midY)
            let bottom = CGPoint(x: rect.midX, y: rect.maxY), left = CGPoint(x: rect.minX, y: rect.midY)
            let outer = DiamondShape().path(in: rect)
            context.fill(outer, with: .linearGradient(Gradient(colors: colors), startPoint: top, endPoint: bottom))
            // Facettes : moitié droite un peu plus sombre, table centrale claire.
            var shade = Path()
            shade.move(to: top); shade.addLine(to: right); shade.addLine(to: bottom); shade.addLine(to: c); shade.closeSubpath()
            context.fill(shade, with: .color(.black.opacity(0.12)))
            let table = DiamondShape().path(in: CGRect(x: c.x - rect.width * 0.2, y: c.y - rect.height * 0.2,
                                                       width: rect.width * 0.4, height: rect.height * 0.4))
            context.fill(table, with: .color(.white.opacity(0.55)))
            var facets = Path()
            for corner in [top, right, bottom, left] { facets.move(to: c); facets.addLine(to: corner) }
            context.stroke(facets, with: .color(outline.opacity(0.25)), lineWidth: max(0.6, canvasSize.width * 0.025))
            context.stroke(outer, with: .color(outline), style: StrokeStyle(lineWidth: max(1, canvasSize.width * 0.07), lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// Indice : un éclat de gemme doré qui scintille.
struct HintIcon: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FacetedGem(size: size * 0.92)
                .frame(width: size, height: size, alignment: .bottomLeading)
            SparkleShape()
                .fill(IconInk.cream)
                .overlay(SparkleShape().stroke(IconInk.outline, lineWidth: max(0.6, size * 0.04)))
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(x: size * 0.08, y: -size * 0.08)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Flamme de la série : deux couches en dégradé.
struct FlameIcon: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            FlameShape()
                .fill(LinearGradient(colors: [Color(hex: "#FFD23D"), Color(hex: "#FF7A1A"), Color(hex: "#E8360E")],
                                     startPoint: .bottom, endPoint: .top))
                .overlay(FlameShape().stroke(IconInk.outline, lineWidth: max(0.8, size * 0.06)))
            FlameShape()
                .fill(LinearGradient(colors: [IconInk.cream, Color(hex: "#FFD23D")], startPoint: .bottom, endPoint: .top))
                .frame(width: size * 0.42, height: size * 0.5)
                .offset(y: size * 0.18)
        }
        .frame(width: size * 0.8, height: size)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.5, y: y))
        path.addCurve(to: CGPoint(x: x + w * 0.95, y: y + h * 0.62),
                      control1: CGPoint(x: x + w * 0.62, y: y + h * 0.22), control2: CGPoint(x: x + w * 0.98, y: y + h * 0.36))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h),
                      control1: CGPoint(x: x + w * 0.95, y: y + h * 0.86), control2: CGPoint(x: x + w * 0.76, y: y + h))
        path.addCurve(to: CGPoint(x: x + w * 0.05, y: y + h * 0.62),
                      control1: CGPoint(x: x + w * 0.24, y: y + h), control2: CGPoint(x: x + w * 0.05, y: y + h * 0.86))
        path.addCurve(to: CGPoint(x: x + w * 0.3, y: y + h * 0.3),
                      control1: CGPoint(x: x + w * 0.05, y: y + h * 0.46), control2: CGPoint(x: x + w * 0.18, y: y + h * 0.4))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y),
                      control1: CGPoint(x: x + w * 0.36, y: y + h * 0.42), control2: CGPoint(x: x + w * 0.5, y: y + h * 0.2))
        path.closeSubpath()
        return path
    }
}

/// Pack de départ : un coffret violet, bande dorée et gemme en serrure, avec des rayons de lumière.
struct ChestIcon: View {
    var size: CGFloat = 44

    var body: some View {
        Canvas { context, s in Self.draw(context, s) }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private static func draw(_ context: GraphicsContext, _ s: CGSize) {
            let w: CGFloat = s.width, h: CGFloat = s.height
            let line: CGFloat = max(1, w * 0.045)
            // Rayons derrière le coffret.
            var rays = Path()
            let center = CGPoint(x: w * 0.5, y: h * 0.42)
            for degrees in stride(from: -70.0, through: 70.0, by: 28.0) {
                let a = CGFloat((degrees - 90) * Double.pi / 180)
                let end = CGPoint(x: center.x + cos(a) * w * 0.5, y: center.y + sin(a) * h * 0.42)
                rays.move(to: center)
                rays.addLine(to: end)
            }
            context.stroke(rays, with: .color(IconInk.gold.opacity(0.7)), style: StrokeStyle(lineWidth: line * 1.2, lineCap: .round))
            let box = CGRect(x: w * 0.12, y: h * 0.48, width: w * 0.76, height: h * 0.44)
            let lid = CGRect(x: w * 0.1, y: h * 0.3, width: w * 0.8, height: h * 0.22)
            let bodyPath = Path(roundedRect: box, cornerRadius: w * 0.06)
            let lidPath = Path(roundedRect: lid, cornerRadius: w * 0.08)
            context.fill(bodyPath, with: .linearGradient(Gradient(colors: [IconInk.violet, IconInk.plum]),
                                                         startPoint: CGPoint(x: 0, y: box.minY), endPoint: CGPoint(x: 0, y: box.maxY)))
            context.fill(lidPath, with: .linearGradient(Gradient(colors: [Color(hex: "#9B82FF"), IconInk.violet]),
                                                        startPoint: CGPoint(x: 0, y: lid.minY), endPoint: CGPoint(x: 0, y: lid.maxY)))
            // Bandes dorées.
            for x in [w * 0.28, w * 0.66] {
                context.fill(Path(CGRect(x: x, y: lid.minY, width: w * 0.06, height: box.maxY - lid.minY)), with: .color(IconInk.gold))
            }
            context.stroke(bodyPath, with: .color(IconInk.outline), lineWidth: line)
            context.stroke(lidPath, with: .color(IconInk.outline), lineWidth: line)
            // Gemme-serrure.
            let gem = DiamondShape().path(in: CGRect(x: w * 0.4, y: h * 0.42, width: w * 0.2, height: h * 0.2))
            context.fill(gem, with: .linearGradient(Gradient(colors: [IconInk.cream, IconInk.gold, IconInk.amber]),
                                                    startPoint: CGPoint(x: 0, y: h * 0.42), endPoint: CGPoint(x: 0, y: h * 0.62)))
            context.stroke(gem, with: .color(IconInk.outline), lineWidth: line * 0.8)
    }
}

/// Sans pub : un écran avec « PUB » barré.
struct NoAdsIcon: View {
    var size: CGFloat = 36
    var tint: Color = IconInk.outline

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(tint, lineWidth: max(1.2, size * 0.07))
                .frame(width: size * 0.86, height: size * 0.64)
            Text("PUB")
                .font(.system(size: size * 0.24, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Capsule()
                .fill(Color(hex: "#E5484D"))
                .frame(width: size * 1.02, height: max(2, size * 0.09))
                .rotationEffect(.degrees(-28))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Thèmes : trois cartes de couleur en éventail.
struct ThemesIcon: View {
    var size: CGFloat = 22
    var colors: [Color] = [Color(hex: "#A6D6F2"), Color(hex: "#B6E7AE"), Color(hex: "#FFC2C2")]

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                    .fill(colors[i % colors.count])
                    .overlay(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                        .stroke(IconInk.outline, lineWidth: max(0.8, size * 0.06)))
                    .frame(width: size * 0.46, height: size * 0.66)
                    .rotationEffect(.degrees(Double(i - 1) * 22), anchor: .bottom)
                    .offset(y: -size * 0.04)
            }
            DiamondShape().fill(IconInk.gold)
                .overlay(DiamondShape().stroke(IconInk.outline, lineWidth: max(0.6, size * 0.04)))
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(y: -size * 0.05)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Classements : une coupe dorée sertie d'une gemme.
struct TrophyIcon: View {
    var size: CGFloat = 22

    var body: some View {
        Canvas { context, s in
            let w = s.width, h = s.height
            let line = max(0.9, w * 0.06)
            var cup = Path()
            cup.move(to: CGPoint(x: w * 0.22, y: h * 0.1))
            cup.addLine(to: CGPoint(x: w * 0.78, y: h * 0.1))
            cup.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.62), control1: CGPoint(x: w * 0.78, y: h * 0.45), control2: CGPoint(x: w * 0.66, y: h * 0.62))
            cup.addCurve(to: CGPoint(x: w * 0.22, y: h * 0.1), control1: CGPoint(x: w * 0.34, y: h * 0.62), control2: CGPoint(x: w * 0.22, y: h * 0.45))
            cup.closeSubpath()
            var handles = Path()
            handles.addArc(center: CGPoint(x: w * 0.22, y: h * 0.26), radius: w * 0.13, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            handles.move(to: CGPoint(x: w * 0.78, y: h * 0.13))
            handles.addArc(center: CGPoint(x: w * 0.78, y: h * 0.26), radius: w * 0.13, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
            context.stroke(handles, with: .color(IconInk.outline), lineWidth: line)
            let base = Path(roundedRect: CGRect(x: w * 0.28, y: h * 0.78, width: w * 0.44, height: h * 0.13), cornerRadius: w * 0.04)
            var stem = Path()
            stem.move(to: CGPoint(x: w * 0.5, y: h * 0.62)); stem.addLine(to: CGPoint(x: w * 0.5, y: h * 0.78))
            context.stroke(stem, with: .color(IconInk.outline), lineWidth: line * 1.6)
            context.fill(cup, with: .linearGradient(Gradient(colors: [IconInk.cream, IconInk.gold, IconInk.amber]),
                                                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h * 0.62)))
            context.stroke(cup, with: .color(IconInk.outline), lineWidth: line)
            context.fill(base, with: .color(IconInk.gold))
            context.stroke(base, with: .color(IconInk.outline), lineWidth: line)
            let gem = DiamondShape().path(in: CGRect(x: w * 0.41, y: h * 0.2, width: w * 0.18, height: h * 0.2))
            context.fill(gem, with: .color(IconInk.violet))
            context.stroke(gem, with: .color(IconInk.outline), lineWidth: line * 0.7)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Parcours : un chemin qui serpente entre trois étapes, jusqu'à une gemme.
struct PathIcon: View {
    var size: CGFloat = 22
    var tint: Color = IconInk.outline

    var body: some View {
        Canvas { context, s in
            let w = s.width, h = s.height
            var road = Path()
            road.move(to: CGPoint(x: w * 0.15, y: h * 0.86))
            road.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.6), control1: CGPoint(x: w * 0.6, y: h * 0.95), control2: CGPoint(x: w * 0.9, y: h * 0.72))
            road.addCurve(to: CGPoint(x: w * 0.34, y: h * 0.3), control1: CGPoint(x: w * 0.5, y: h * 0.46), control2: CGPoint(x: w * 0.2, y: h * 0.45))
            road.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.16), control1: CGPoint(x: w * 0.45, y: h * 0.16), control2: CGPoint(x: w * 0.6, y: h * 0.12))
            context.stroke(road, with: .color(tint.opacity(0.75)), style: StrokeStyle(lineWidth: max(1, w * 0.07), lineCap: .round, dash: [w * 0.1, w * 0.08]))
            for p in [CGPoint(x: w * 0.15, y: h * 0.86), CGPoint(x: w * 0.72, y: h * 0.6), CGPoint(x: w * 0.34, y: h * 0.3)] {
                let dot = Path(ellipseIn: CGRect(x: p.x - w * 0.08, y: p.y - w * 0.08, width: w * 0.16, height: w * 0.16))
                context.fill(dot, with: .color(tint))
            }
            let gem = DiamondShape().path(in: CGRect(x: w * 0.64, y: 0, width: w * 0.3, height: h * 0.32))
            context.fill(gem, with: .color(IconInk.gold))
            context.stroke(gem, with: .color(IconInk.outline), lineWidth: max(0.8, w * 0.05))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Mode Libre : une mini-grille 3 × 3 avec deux gemmes reliées.
struct FreeIcon: View {
    var size: CGFloat = 22
    var tint: Color = IconInk.outline

    var body: some View {
        Canvas { context, s in
            let w = s.width, c = w / 3
            let colors = [Color(hex: "#FFC2C2"), Color(hex: "#FFE28A"), Color(hex: "#A6D6F2")]
            let zones = [0, 0, 1, 2, 0, 1, 2, 2, 1]
            for i in 0..<9 {
                let r = CGRect(x: CGFloat(i % 3) * c, y: CGFloat(i / 3) * c, width: c, height: c)
                context.fill(Path(r), with: .color(colors[zones[i]]))
            }
            context.stroke(Path(roundedRect: CGRect(origin: .zero, size: s).insetBy(dx: 0.5, dy: 0.5), cornerRadius: w * 0.12),
                           with: .color(tint), lineWidth: max(1, w * 0.07))
            var beam = Path()
            beam.move(to: CGPoint(x: c * 0.5, y: c * 0.5)); beam.addLine(to: CGPoint(x: c * 2.5, y: c * 0.5)); beam.addLine(to: CGPoint(x: c * 2.5, y: c * 2.5))
            context.stroke(beam, with: .color(IconInk.amber), style: StrokeStyle(lineWidth: max(1, w * 0.08), lineCap: .round, lineJoin: .round))
            for i in [0, 2, 8] {
                let r = CGRect(x: CGFloat(i % 3) * c, y: CGFloat(i / 3) * c, width: c, height: c).insetBy(dx: c * 0.18, dy: c * 0.18)
                context.fill(DiamondShape().path(in: r), with: .color(.white))
                context.stroke(DiamondShape().path(in: r), with: .color(IconInk.outline), lineWidth: max(0.6, w * 0.035))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Médaille « sans indice » : une petite gemme pure dans un cercle doré.
struct MedalIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [IconInk.cream, IconInk.gold], startPoint: .top, endPoint: .bottom))
            Circle().stroke(IconInk.outline, lineWidth: max(0.8, size * 0.08))
            DiamondShape().fill(Color(hex: "#7B5CFF"))
                .overlay(DiamondShape().stroke(IconInk.outline, lineWidth: max(0.5, size * 0.05)))
                .frame(width: size * 0.48, height: size * 0.48)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Sans indice")
    }
}
