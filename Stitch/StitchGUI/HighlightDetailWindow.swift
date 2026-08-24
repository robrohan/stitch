import SwiftUI
import AppKit

/// Keeps detail windows alive for as long as they're open — a locally
/// scoped NSWindowController would be deallocated (and its window closed)
/// the instant the function that created it returns.
final class DetailWindowManager {
    static let shared = DetailWindowManager()

    private var controllers: [NSWindowController] = []

    func open(highlight: Highlight) {
        let hosting = NSHostingController(rootView: HighlightDetailView(highlight: highlight))
        let window = NSWindow(contentViewController: hosting)
        window.title = highlight.title.isEmpty ? "Highlight" : highlight.title
        window.setContentSize(NSSize(width: 480, height: 320))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        controllers.append(controller)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.controllers.removeAll { $0.window === window }
        }
    }
}

struct HighlightDetailView: View {
    let highlight: Highlight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if !highlight.title.isEmpty {
                    Text(highlight.title).font(.headline)
                }
                let subtitle = [highlight.author, highlight.date].filter { !$0.isEmpty }.joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView {
                Text(highlight.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !highlight.annotation.isEmpty {
                Divider()
                Text("Note").font(.caption).foregroundStyle(.secondary)
                Text(highlight.annotation)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("Copy Text") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(highlight.text, forType: .string)
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 260)
    }
}
