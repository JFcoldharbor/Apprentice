//
//  AriaTheme.swift
//  Apprentice
//
//  Design system for the "Aria — Executive Intelligence" redesign.
//  Palette, type ramp, background, and shared header components translated
//  1:1 from the aria-redesign.html mockup (CSS variables + classes).
//

import SwiftUI

// MARK: - Palette

enum Aria {
    static let bg          = Color(ariaHex: 0x05070D)   // body background
    static let ink         = Color(ariaHex: 0x0B0F1A)   // --ink
    static let panel       = Color(ariaHex: 0x141A2A)   // --panel
    static let panel2      = Color(ariaHex: 0x1A2236)   // --panel-2
    static let ivory       = Color(ariaHex: 0xF2EDE4)   // --ivory
    static let ivoryDim    = Color(ariaHex: 0x9AA0AE)   // --ivory-dim
    static let ivoryFaint  = Color(ariaHex: 0x5E6573)   // --ivory-faint
    static let gold        = Color(ariaHex: 0xC9A86A)   // --gold
    static let goldBright  = Color(ariaHex: 0xE2C78C)   // --gold-bright
    static let jade        = Color(ariaHex: 0x7FA890)   // --jade
    static let rose        = Color(ariaHex: 0xB98A7A)   // --rose

    static let line     = gold.opacity(0.14)            // --line
    static let lineSoft = ivory.opacity(0.07)           // --line-soft
    static let radius: CGFloat = 22

    // Type families (PostScript names of the bundled fonts)
    enum Serif { case regular, medium, semibold, italic
        var ps: String {
            switch self {
            case .regular:  return "Fraunces-Regular"
            case .medium:   return "Fraunces-Medium"
            case .semibold: return "Fraunces-SemiBold"
            case .italic:   return "Fraunces-Italic"
            }
        }
    }
    enum Sans { case regular, medium, semibold
        var ps: String {
            switch self {
            case .regular:  return "Inter-Regular"
            case .medium:   return "Inter-Medium"
            case .semibold: return "Inter-SemiBold"
            }
        }
    }
    enum Mono { case regular, medium
        var ps: String {
            switch self {
            case .regular: return "JetBrainsMono-Regular"
            case .medium:  return "JetBrainsMono-Medium"
            }
        }
    }
}

extension Color {
    fileprivate init(ariaHex hex: UInt) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Fonts

extension Font {
    static func fraunces(_ size: CGFloat, _ w: Aria.Serif = .regular) -> Font { .custom(w.ps, size: size) }
    static func inter(_ size: CGFloat, _ w: Aria.Sans = .regular) -> Font { .custom(w.ps, size: size) }
    static func ariaMono(_ size: CGFloat, _ w: Aria.Mono = .regular) -> Font { .custom(w.ps, size: size) }
}

// MARK: - Background

struct AriaBackground: View {
    var body: some View {
        ZStack {
            Aria.bg
            RadialGradient(
                colors: [Color(ariaHex: 0x18203A), .clear],
                center: UnitPoint(x: 0.5, y: -0.10),
                startRadius: 0, endRadius: 540
            )
            RadialGradient(
                colors: [Color(ariaHex: 0x1A1426), .clear],
                center: UnitPoint(x: 1.0, y: 1.10),
                startRadius: 0, endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Header pieces (.eyebrow / h1 / .sub)

struct AriaEyebrow: View {
    let text: String
    var body: some View {
        HStack(spacing: 9) {
            Rectangle().fill(Aria.gold.opacity(0.6)).frame(width: 18, height: 1)
            Text(text.uppercased())
                .font(.ariaMono(10.5))
                .tracking(3)
                .foregroundColor(Aria.gold)
        }
    }
}

/// h1 with an italic gold emphasis span, e.g. AriaTitle("Your ", em: "sessions").
struct AriaTitle: View {
    let plain: String
    let em: String
    var size: CGFloat = 40
    var body: some View {
        (
            Text(plain).font(.fraunces(size, .regular)).foregroundColor(Aria.ivory)
            + Text(em).font(.fraunces(size, .italic)).foregroundColor(Aria.goldBright)
        )
        .tracking(-0.5)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct AriaSub: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.inter(14.5))
            .foregroundColor(Aria.ivoryDim)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AriaSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.ariaMono(10.5))
            .tracking(2.5)
            .foregroundColor(Aria.ivoryFaint)
    }
}

// MARK: - Card surface

extension View {
    /// .panel surface with a soft hairline border (matches .metric / .session / .q-card).
    func ariaCard(_ padding: CGFloat = 18, radius: CGFloat = 18,
                  fill: Color = Aria.panel, stroke: Color = Aria.lineSoft) -> some View {
        self.padding(padding)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}
