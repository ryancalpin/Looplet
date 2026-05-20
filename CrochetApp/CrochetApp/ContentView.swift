import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore

    var body: some View {
        NavigationSplitView {
            PatternLibraryView(library: library, store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                // Sticky counter bar — always visible
                CounterBarView(store: store)

                // Scrollable markdown viewer
                MarkdownView(fileURL: activeFileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(library.activeEntry?.displayName ?? "Crochet Helper")
        .background(KeyboardShortcutHandler(store: store))
    }

    private var activeFileURL: URL? {
        guard let entry = library.activeEntry else { return nil }
        let url = entry.resolveURL()
        url?.startAccessingSecurityScopedResource()
        return url
    }
}

// MARK: - Keyboard Shortcut Handler

struct KeyboardShortcutHandler: NSViewRepresentable {
    @ObservedObject var store: CounterStore

    func makeNSView(context: Context) -> KeyHandlerView {
        let view = KeyHandlerView()
        view.store = store
        return view
    }

    func updateNSView(_ nsView: KeyHandlerView, context: Context) {
        nsView.store = store
    }
}

class KeyHandlerView: NSView {
    var store: CounterStore?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let store = store else { super.keyDown(with: event); return }
        let mods = event.modifierFlags.intersection([.command, .option, .control])
        guard mods.isEmpty else { super.keyDown(with: event); return }

        switch event.keyCode {
        case 126: store.incrementRow()
        case 125: store.decrementRow()
        case 124: store.incrementStitch()
        case 123: store.decrementStitch()
        default:
            switch event.charactersIgnoringModifiers {
            case "R": store.incrementRow()
            case "r": store.decrementRow()
            case "S": store.incrementStitch()
            case "s": store.decrementStitch()
            default: super.keyDown(with: event)
            }
        }
    }
}

#Preview {
    ContentView(library: PatternLibrary(), store: CounterStore())
        .frame(width: 960, height: 650)
}
