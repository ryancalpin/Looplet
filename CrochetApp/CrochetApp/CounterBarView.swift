import SwiftUI

struct CounterBarView: View {
    @ObservedObject var store: CounterStore
    @State private var showResetConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            // Row counter pill
            counterPill(
                label: "Row",
                count: store.rowCount,
                color: .pink,
                accentColor: Color(red: 0.71, green: 0.33, blue: 0.49),
                onDecrement: { withAnimation { store.decrementRow() } },
                onIncrement: { withAnimation { store.incrementRow() } }
            )

            // Stitch counter pill
            counterPill(
                label: "Stitch",
                count: store.stitchCount,
                color: Color.purple,
                accentColor: Color(red: 0.49, green: 0.30, blue: 0.80),
                onDecrement: { withAnimation { store.decrementStitch() } },
                onIncrement: { withAnimation { store.incrementStitch() } }
            )

            Divider()
                .frame(height: 32)

            // Auto-reset toggle
            HStack(spacing: 6) {
                Toggle("", isOn: $store.autoResetStitch)
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .onChange(of: store.autoResetStitch) { newValue in
                        store.library?.updateActiveCounters(
                            row: store.rowCount,
                            stitch: store.stitchCount,
                            autoReset: newValue
                        )
                    }
                Text("Auto-reset")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Keyboard hint
            Text("↑↓ row · ←→ stitch")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))

            Divider()
                .frame(height: 32)

            // Reset button
            Button("Reset") {
                showResetConfirmation = true
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
            .confirmationDialog(
                "Reset counters?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { store.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Row and Stitch counts will be set to 0.")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func counterPill(
        label: String,
        count: Int,
        color: Color,
        accentColor: Color,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .foregroundColor(count == 0 ? Color.secondary : accentColor)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)

            Divider().frame(height: 36)

            VStack(spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(accentColor)
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: count)
            }
            .frame(minWidth: 52)
            .padding(.horizontal, 6)

            Divider().frame(height: 36)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .foregroundColor(accentColor)
            }
            .buttonStyle(.plain)
        }
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.25), lineWidth: 1.5)
        )
    }
}
