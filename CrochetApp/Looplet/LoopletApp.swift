import SwiftUI

@main
struct LoopletApp: App {
    @StateObject private var library = PatternLibrary()
    @StateObject private var store = CounterStore()
    @StateObject private var sessionTimer = SessionTimer()
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView(library: library, store: store, sessionTimer: sessionTimer)
                #if os(macOS)
                .frame(minWidth: 700, minHeight: 500)
                #endif
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .onAppear {
                    store.library = library
                }
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Button("Toggle Focus Mode") {
                    NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
            }
            CommandGroup(after: .help) {
                Button("Welcome to Looplet") {
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                }
                Button("Unlock Looplet Pro…") {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                }
                Button("Send Feedback & Suggestions…") {
                    if let url = URL(string: AppSettings.feedbackURLString) {
                        openExternalURL(url)
                    }
                }
                Divider()
                Button("Reset All Counters…") {
                    NotificationCenter.default.post(name: .resetAllCounters, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

extension Notification.Name {
    static let resetAllCounters = Notification.Name("Looplet.resetAllCounters")
    static let toggleFocusMode = Notification.Name("Looplet.toggleFocusMode")
    static let showPaywall = Notification.Name("Looplet.showPaywall")
    static let showOnboarding = Notification.Name("Looplet.showOnboarding")
}
