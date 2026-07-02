import SwiftUI
import AppKit

@main
struct TimekeepApp: App {
    // Ensure the app activates as a regular foreground window even when launched
    // from a bare executable during development.
    init() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()
        }
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 680, minHeight: 560)
                .background(Theme.page)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1160, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {} // no "New" window
        }
    }
}
