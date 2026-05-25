import SwiftUI

// MARK: - onChange compatibility shim
//
// The two-parameter and zero-parameter `onChange(of:)` forms require macOS 14 / iOS 17,
// but the app targets macOS 13+. The deprecated one-parameter form compiles on macOS 13
// but generates deprecation warnings on iOS 17+. This ViewModifier wraps both so call
// sites stay warning-free across the full deployment range.

/// Call when you need the new value in the action closure.
extension View {
    func onChangeValue<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        modifier(OnChangeValueModifier(value: value, action: action))
    }

    /// Call when you only need to run a side-effect (no value needed).
    func onChangeEffect<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        modifier(OnChangeEffectModifier(value: value, action: action))
    }
}

private struct OnChangeValueModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (V) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            content.onChange(of: value, perform: action)
        }
    }
}

private struct OnChangeEffectModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.onChange(of: value) { action() }
        } else {
            content.onChange(of: value) { _ in action() }
        }
    }
}
