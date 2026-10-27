import Foundation

/// Feature flags matching the web app. Flip these to reveal gated UI.
/// Full data model and logic stay implemented even when flags are false.
enum Features {
    /// To-Do/Calendar tab, notification bar, Complete To-Do's row.
    static let todoCalendar = false

    /// Daily Progress bars, Perfect Day streak badge, Planned Next Day.
    /// Full-time quotas apply Mon–Fri; weekends use the part-time extra automatically.
    static let dailyProgress = true

    /// Daily Reflection highlight + rating slider.
    static let dailyReflection = true
}
