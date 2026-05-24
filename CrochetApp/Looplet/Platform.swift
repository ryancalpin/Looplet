import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

// Cross-platform shims so the rest of the app can stay free of `#if os(...)`.
// AppKit and UIKit diverge on color, app lifecycle, and URL opening; everything
// here resolves to the right framework at compile time.

// MARK: - Color construction

/// Build an sRGB platform color from 0...1 components.
func platformSRGBColor(red r: CGFloat, green g: CGFloat, blue b: CGFloat, alpha a: CGFloat = 1) -> PlatformColor {
    #if canImport(UIKit)
    return UIColor(red: r, green: g, blue: b, alpha: a)
    #else
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    #endif
}

/// A SwiftUI `Color` that resolves its light/dark value at draw time from the
/// current appearance — the cross-platform replacement for `NSColor(name:)`.
func platformDynamicColor(_ provider: @escaping (_ isDark: Bool) -> PlatformColor) -> Color {
    #if canImport(UIKit)
    return Color(UIColor { traits in provider(traits.userInterfaceStyle == .dark) })
    #else
    return Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return provider(isDark)
    })
    #endif
}

// MARK: - Opening external URLs

@MainActor func openExternalURL(_ url: URL) {
    #if canImport(UIKit)
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    #elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
}

// MARK: - App lifecycle notification names

extension Notification.Name {
    /// App is about to lose foreground/active status.
    static var appResignActive: Notification.Name {
        #if canImport(UIKit)
        return UIApplication.willResignActiveNotification
        #else
        return NSApplication.didResignActiveNotification
        #endif
    }

    /// App became active/foreground.
    static var appBecomeActive: Notification.Name {
        #if canImport(UIKit)
        return UIApplication.didBecomeActiveNotification
        #else
        return NSApplication.didBecomeActiveNotification
        #endif
    }

    /// App is about to terminate (macOS) or has moved to the background (iOS,
    /// where termination isn't guaranteed) — the moment to flush unsaved state.
    static var appWillPersistState: Notification.Name {
        #if canImport(UIKit)
        return UIApplication.didEnterBackgroundNotification
        #else
        return NSApplication.willTerminateNotification
        #endif
    }
}
