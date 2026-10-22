import SwiftUI

enum Theme {
    static let bg = Color.black
    static let card = Color(hex: 0x161819)
    static let card2 = Color(hex: 0x1F2224)
    static let line = Color(hex: 0x2A2E31)
    static let text = Color(hex: 0xF2F4F5)
    static let muted = Color(hex: 0x9AA3A8)
    static let dim = Color(hex: 0x6B7479)
    static let faint = Color(hex: 0x4A5258)
    static let accent = Color(hex: 0x1EA7E1)
    static let green = Color(hex: 0x3DDC84)
    static let red = Color(hex: 0xFF4D4D)
    static let orange = Color(hex: 0xFF8A3D)
    static let paper = Color(hex: 0xF4F5F6)
    static let ink = Color(hex: 0x111416)

    // Santé section
    static let health = Color(hex: 0xFF375F)
    static let healthSoft = Color(hex: 0xFF6F8A)
    static let healthBg = Color(hex: 0x12090C)
    static let healthCard = Color(hex: 0x1C1114)
    static let healthMuted = Color(hex: 0xB39AA1)
    static let healthLine = Color(hex: 0x3A1520)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    /// Big condensed figures, Garmin style.
    static func num(_ size: CGFloat) -> Font { .system(size: size, weight: .bold).width(.condensed) }
    static let label = Font.system(size: 11, weight: .bold)
}

struct SectionLabel: View {
    var text: String
    var color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(.label).tracking(2).foregroundStyle(color)
    }
}

struct Card: ViewModifier {
    var fill = Theme.card
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func card(_ fill: Color = Theme.card, padding: CGFloat = 16) -> some View { modifier(Card(fill: fill, padding: padding)) }
}

/// Scrollable page with the phone-width column centred on the Mac.
struct Screen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
        .foregroundStyle(Theme.text)
    }
}

/// Thin horizontal progress bar.
struct Bar: View {
    var value: Double
    var color = Theme.accent
    var height: CGFloat = 6
    var track = Theme.line
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color).frame(width: g.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
    }
}

struct ArrowButton: View {
    var left: Bool
    var enabled = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.muted : Theme.faint)
        .disabled(!enabled)
        .accessibilityLabel(left ? "Previous" : "Next")
    }
}

extension View {
    /// Swipe right → previous, swipe left → next.
    func swipe(previous: @escaping () -> Void, next: @escaping () -> Void) -> some View {
        gesture(DragGesture(minimumDistance: 30).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) else { return }
            if v.translation.width > 50 { withAnimation(.snappy) { previous() } }
            if v.translation.width < -50 { withAnimation(.snappy) { next() } }
        })
    }
}
