import SwiftUI

extension Font {
    /// Classical serif (New York) — used throughout simply.
    static func stoic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

enum AppTheme {
    static let background = Color(red: 0.10, green: 0.10, blue: 0.145)
    static let card = Color(red: 0.165, green: 0.165, blue: 0.22)
    static let secondary = Color(red: 0.20, green: 0.20, blue: 0.26)
    static let muted = Color(red: 0.21, green: 0.21, blue: 0.27)
    static let border = Color(red: 0.32, green: 0.32, blue: 0.42)
    static let text = Color(red: 0.93, green: 0.93, blue: 0.96)
    static let mutedText = Color(red: 0.66, green: 0.66, blue: 0.74)
    static let primary = Color(red: 0.55, green: 0.58, blue: 0.95)
    static let destructive = Color(red: 0.92, green: 0.35, blue: 0.32)

    static func palette(_ color: PaletteColor) -> Color {
        switch color {
        case .violet: return Color(red: 0.55, green: 0.36, blue: 0.96)
        case .sky: return Color(red: 0.08, green: 0.72, blue: 0.96)
        case .emerald: return Color(red: 0.10, green: 0.78, blue: 0.55)
        case .amber: return Color(red: 0.96, green: 0.62, blue: 0.07)
        case .rose: return Color(red: 0.96, green: 0.35, blue: 0.47)
        case .cyan: return Color(red: 0.13, green: 0.83, blue: 0.93)
        case .orange: return Color(red: 0.98, green: 0.55, blue: 0.20)
        case .fuchsia: return Color(red: 0.85, green: 0.32, blue: 0.85)
        }
    }

    static func blockAccent(_ category: HabitCategory) -> Color {
        switch category {
        case .morning: return palette(.amber)
        case .dayActivities: return palette(.sky)
        case .dayHabits: return Color(red: 0.18, green: 0.77, blue: 0.71)
        case .night: return Color(red: 0.45, green: 0.47, blue: 0.95)
        }
    }

    static func scopeAccent(_ scope: TodoScope) -> Color {
        switch scope {
        case .timed: return palette(.violet)
        case .day: return palette(.sky)
        case .week: return palette(.amber)
        case .month: return palette(.emerald)
        }
    }
}

struct TimeBlockCardStyle: ViewModifier {
    var accent: Color

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.28), AppTheme.card, AppTheme.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.55), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}

extension View {
    @ViewBuilder
    func optionalGesture<G: Gesture>(_ gesture: G?) -> some View {
        if let gesture {
            self.gesture(gesture)
        } else {
            self
        }
    }

    func timeBlockCard(_ accent: Color) -> some View {
        modifier(TimeBlockCardStyle(accent: accent))
    }

    func chromeCard(accent: Color = AppTheme.border) -> some View {
        padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.7), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}
