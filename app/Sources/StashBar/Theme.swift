import AppKit
import CoreText
import SwiftUI

// MARK: - Colour tokens (from the design system)

enum Palette {
    static let ink = Color(hex: 0x0C0A08)
    static let charcoal = Color(hex: 0x1A1919)
    static let graphite = Color(hex: 0x2A2828)
    static let graphiteLine = Color(hex: 0x3D3B3A)
    static let accent = Color(hex: 0xE4F222)
    static let white = Color.white
    static let beige = Color(hex: 0xF4F2F0)
    static let line = Color(hex: 0xEBE6DF)
    static let sand = Color(hex: 0xD9D2C7)
    static let muted = Color(hex: 0x6D6C6B)
    static let mutedOnDark = Color(hex: 0xA3A2A1)
}

/// Semantic colours that flip in dark mode. Dark sidebars stay dark in both modes.
enum Tok {
    static let bg = dyn(light: 0xFFFFFF, dark: 0x141211)
    static let surface = dyn(light: 0xF4F2F0, dark: 0x221F1D)
    static let line = dyn(light: 0xEBE6DF, dark: 0x34302D)
    static let sand = dyn(light: 0xD9D2C7, dark: 0x4A4541)
    static let text = dyn(light: 0x0C0A08, dark: 0xF4F2F0)
    static let muted = dyn(light: 0x6D6C6B, dark: 0xA3A2A1)
    static let popoverBg = dyn(light: 0xFFFFFF, dark: 0x1A1919)

    // Sidebars (canvas + Settings): light beige in light mode, charcoal in dark mode.
    static let sidebarBg = dyn(light: 0xF4F2F0, dark: 0x1A1919)
    static let sidebarText = dyn(light: 0x0C0A08, dark: 0xFFFFFF)
    static let sidebarMuted = dyn(light: 0x6D6C6B, dark: 0xA3A2A1)
    static let sidebarCard = dyn(light: 0xFFFFFF, dark: 0x2A2828)
    static let sidebarLine = dyn(light: 0xEBE6DF, dark: 0x3D3B3A)

    static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - Typography

enum Fonts {
    /// Duplet if the user has it installed (licensed locally), otherwise the bundled Outfit (OFL).
    private(set) static var family = "Outfit"

    static func register() {
        if let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
           let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for url in files where url.pathExtension == "ttf" || url.pathExtension == "otf" {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        if NSFontManager.shared.availableFontFamilies.contains("Duplet") {
            family = "Duplet"
        }
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let w: NSFont.Weight = weight == .medium ? .medium : (weight == .semibold ? .semibold : .regular)
        return Font(nsFont(size, w))
    }

    static func nsFont(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        let wantsBold = weight != .regular
        if family == "Duplet" {
            let name = wantsBold ? "Duplet-Semibold" : "Duplet-Regular"
            if let f = NSFont(name: name, size: size) { return withSS01(f) }
        }
        let name = weight == .semibold ? "Outfit-SemiBold" : (wantsBold ? "Outfit-Medium" : "Outfit-Regular")
        if let f = NSFont(name: name, size: size) { return f }
        // Font name lookup by family+weight as a fallback.
        if let f = NSFontManager.shared.font(withFamily: "Outfit", traits: [], weight: wantsBold ? 7 : 5, size: size) {
            return f
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    private static func withSS01(_ font: NSFont) -> NSFont {
        let settings: [[NSFontDescriptor.FeatureKey: Int]] = [
            [.typeIdentifier: kStylisticAlternativesType, .selectorIdentifier: kStylisticAltOneOnSelector],
        ]
        let d = font.fontDescriptor.addingAttributes([.featureSettings: settings])
        return NSFont(descriptor: d, size: font.pointSize) ?? font
    }
}

extension View {
    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        self.font(Fonts.ui(size, weight))
    }

    /// Display headings: medium weight, -0.04em tracking.
    func heading(_ size: CGFloat) -> some View {
        self.font(Fonts.ui(size, .medium)).tracking(-0.04 * size).lineSpacing(size * 0.02)
    }
}

// MARK: - Icons (Hugeicons rendered to vector PDF, used as template images)

struct Icon: View {
    let name: String
    var size: CGFloat = 15
    var color: Color = Tok.text

    var body: some View {
        if let img = IconCache.image(name) {
            Image(nsImage: img)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .frame(width: size, height: size)
                .foregroundColor(color)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}

enum IconCache {
    private static var cache: [String: NSImage] = [:]

    static func image(_ name: String) -> NSImage? {
        if let img = cache[name] { return img }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Icons/\(name).pdf"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        cache[name] = img
        return img
    }

    /// Full-colour (non-template) image such as the app icon artwork.
    static func artwork(_ name: String) -> NSImage? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Icons/\(name).pdf") else { return nil }
        return NSImage(contentsOf: url)
    }
}

struct Artwork: View {
    let name: String
    var size: CGFloat
    var body: some View {
        if let img = IconCache.artwork(name) {
            Image(nsImage: img).resizable().interpolation(.high).frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.23).fill(Palette.accent).frame(width: size, height: size)
        }
    }
}

/// The StashBar pin mark, tinted.
struct PinMark: View {
    var size: CGFloat = 16
    var color: Color = Tok.text
    var body: some View { Icon(name: "pin-mark-ink", size: size, color: color) }
}

/// Site logo for a domain, falling back to a globe.
enum SiteLogo {
    static let map: [String: String] = [
        "github.com": "github", "x.com": "twitter", "twitter.com": "twitter", "t.co": "twitter",
        "youtube.com": "youtube", "youtu.be": "youtube", "m.youtube.com": "youtube",
        "developer.apple.com": "apple", "apple.com": "apple", "figma.com": "figma",
        "stripe.com": "credit-card", "arxiv.org": "file-text", "nytimes.com": "file-text",
        "medium.com": "book-open", "reddit.com": "message-circle", "old.reddit.com": "message-circle",
        "notion.so": "notebook", "notion.site": "notebook", "google.com": "chrome",
        "docs.google.com": "file-text", "news.ycombinator.com": "message-circle",
    ]

    static func icon(for domain: String) -> String {
        if let m = map[domain] { return m }
        // Match subdomains like gist.github.com
        for (k, v) in map where domain.hasSuffix("." + k) { return v }
        return "globe"
    }
}

// MARK: - Components

enum Radius {
    static let small: CGFloat = 6
    static let control: CGFloat = 10
    static let card: CGFloat = 16
}

struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var fullWidth = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(14, .medium)
            .foregroundColor(Palette.ink)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.accent))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var fullWidth = false
    var onDark = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(13)
            .foregroundColor(onDark ? .white : Tok.text)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: Radius.control)
                .fill(configuration.isPressed ? Tok.surface : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: Radius.control)
                .strokeBorder(onDark ? Palette.muted : Tok.text, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Rectangle())
    }
}

struct DarkButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var fullWidth = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(13, .medium)
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.charcoal))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Rectangle())
    }
}

struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var fullWidth = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(14)
            .foregroundColor(Tok.text)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

/// Small square icon button (28–40px) with a 1px border.
struct IconButton: View {
    let icon: String
    var size: CGFloat = 28
    var iconSize: CGFloat = 13
    var help: String = ""
    var filled = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Icon(name: icon, size: iconSize, color: filled || hover ? Palette.ink : Tok.text)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: Radius.control)
                    .fill(filled || hover ? Palette.accent : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: Radius.control)
                    .strokeBorder(filled || hover ? Palette.accent : Tok.line, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
        .accessibilityLabel(help)
    }
}

/// Toggle drawn like the design: 42×24 pill, ink track + yellow knob when on.
struct PillToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Palette.ink : Tok.sand)
                Circle().fill(isOn ? Palette.accent : Color.white)
                    .frame(width: 18, height: 18)
                    .padding(3)
            }
            .frame(width: 42, height: 24)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Segmented control: 10px frame, 3px inset, 7px selected option.
struct Segmented: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { opt in
                Button { selection = opt } label: {
                    Text(opt)
                        .font(12)
                        .foregroundColor(selection == opt ? .white : Tok.text)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7)
                            .fill(selection == opt ? Palette.ink : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Tok.line, lineWidth: 1))
    }
}

/// Keyboard keycap (e.g. ⌥ S).
struct KeyCap: View {
    var icon: String? = nil
    var label: String
    var height: CGFloat = 30
    var body: some View {
        HStack(spacing: 3) {
            if let icon { Icon(name: icon, size: 13, color: Palette.ink) }
            Text(label).font(13, .medium).foregroundColor(Palette.ink)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Palette.sand, lineWidth: 1))
        .shadow(color: Palette.sand, radius: 0, x: 0, y: 2)
    }
}

/// Uppercase small section label.
struct SectionLabel: View {
    let text: String
    var color: Color = Tok.muted
    var body: some View { Text(text.uppercased()).font(12).foregroundColor(color) }
}

/// Logo tile used in link rows.
struct LogoTile: View {
    let domain: String
    var size: CGFloat = 32
    var iconSize: CGFloat = 15
    var body: some View {
        Icon(name: SiteLogo.icon(for: domain), size: iconSize)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
    }
}

/// Text field styled as the design's beige search box.
struct SearchField: View {
    var placeholder: String
    @Binding var text: String
    var height: CGFloat = 40
    var token: String? = nil
    var onClearToken: (() -> Void)? = nil
    var focus: FocusState<Bool>.Binding? = nil
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Icon(name: "search", size: 15).opacity(0.55)
            if let token {
                Button { onClearToken?() } label: {
                    HStack(spacing: 4) {
                        Text(token).font(12)
                        Icon(name: "x", size: 10, color: .white)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.charcoal))
                }
                .buttonStyle(.plain)
                .help("Remove filter")
            }
            field
            if !text.isEmpty {
                Button { text = "" } label: { Icon(name: "x", size: 12, color: Tok.muted) }
                    .buttonStyle(.plain)
                    .help("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
    }

    @ViewBuilder private var field: some View {
        let tf = TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Tok.muted))
            .textFieldStyle(.plain)
            .font(13)
            .foregroundColor(Tok.text)
            .onSubmit(onSubmit)
        if let focus { tf.focused(focus) } else { tf }
    }
}

/// Avatar circle: photo or monogram.
struct Avatar: View {
    let account: Account?
    var size: CGFloat = 30
    var body: some View {
        Group {
            if let account {
                if let data = account.photo, let img = NSImage(data: data) {
                    Image(nsImage: img).resizable().scaledToFill()
                } else {
                    let style = MonogramStyle(rawValue: account.monogramStyle) ?? .ink
                    Text(account.initials)
                        .font(Fonts.ui(size * 0.36, .medium))
                        .tracking(-0.04 * size * 0.36)
                        .foregroundColor(style.fg)
                        .frame(width: size, height: size)
                        .background(style.bg)
                        .overlay(Circle().strokeBorder(style.border, lineWidth: style == .ink ? 0 : 1))
                }
            } else {
                Icon(name: "user-round", size: size * 0.45, color: Palette.mutedOnDark)
                    .frame(width: size, height: size)
                    .overlay(Circle().strokeBorder(Palette.mutedOnDark, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

enum MonogramStyle: Int, CaseIterable {
    case ink = 0, accent, beige, white
    var bg: Color {
        switch self {
        case .ink: return Palette.charcoal
        case .accent: return Palette.accent
        case .beige: return Palette.beige
        case .white: return .white
        }
    }
    var fg: Color { self == .ink ? Palette.accent : Palette.ink }
    var border: Color { self == .ink ? .clear : Palette.line }
}

/// Modal card used for all dialogs.
struct DialogCard<Content: View>: View {
    var width: CGFloat = 440
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .padding(28)
            .frame(width: width)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.bg))
            .shadow(color: .black.opacity(0.25), radius: 35, y: 30)
    }
}

/// Dim backdrop with a centred dialog.
struct DialogOverlay<Content: View>: View {
    var onDismiss: (() -> Void)?
    @ViewBuilder let content: Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss?() }
            content
        }
        .transition(.opacity)
    }
}

/// Toast shown at the bottom of a window.
struct Toast: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            PinMark(size: 14, color: Palette.accent)
            Text(text).font(13).foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.charcoal))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

/// Traffic-light spacer for windows with hidden title bars.
struct TitlebarSpacer: View {
    var body: some View { Color.clear.frame(height: 28) }
}

extension View {
    @ViewBuilder func `if`<T: View>(_ cond: Bool, transform: (Self) -> T) -> some View {
        if cond { transform(self) } else { self }
    }
}
