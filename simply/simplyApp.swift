import SwiftUI

@main
struct simplyApp: App {
    @StateObject private var store = TrackerStore()

    init() {
        AppFonts.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup("simply — Daily planner & habit tracker") {
            AppShellView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .background(AppTheme.background)
                .fontDesign(.serif)
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1320, height: 860)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
