import SwiftUI
import AppKit

struct ContentView: View {
    @State private var device: DeviceType = .kindle
    @State private var inputPath: String = DeviceType.kindle.defaultInputPath
    @State private var outputPath: String = ContentView.defaultOutputPath(for: .kindle)

    @State private var highlights: [Highlight] = []
    @State private var searchText: String = ""
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    @State private var lastExportCount: Int?

    @State private var sortOrder: [KeyPathComparator<Highlight>] = []
    // Single selection only: a Set<Highlight.ID> binding lets click-drag do a
    // continuous multi-row select, firing a fresh selection mutation (and a
    // full Table re-render, gesture recognizers included) on every row the
    // drag crosses — that's what made an accidental drag-select feel like the
    // table had locked up.
    @State private var selection: Highlight.ID?

    // Backs the Table directly. Rebuilt only when highlights/searchText/sortOrder
    // actually change (see the .onChange handlers below), rather than on every
    // body re-evaluation — handing Table a fresh array identity on unrelated
    // state changes (e.g. typing in the search field) forces it to re-diff its
    // backing NSTableView, and a click landing mid-diff can get dropped, which
    // shows up as the table intermittently not responding to clicks.
    @State private var displayedHighlights: [Highlight] = []

    @State private var isHoveringTable = false
    @State private var doubleClickMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Picker("Device", selection: $device) {
                    ForEach(DeviceType.allCases) { device in
                        Text(device.rawValue).tag(device)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: device) { _, newDevice in
                    inputPath = newDevice.defaultInputPath
                    outputPath = ContentView.defaultOutputPath(for: newDevice)
                }

                LabeledContent("Input") {
                    HStack {
                        TextField("Input file", text: $inputPath)
                        Button("Choose…") { chooseInput() }
                    }
                }

                LabeledContent("Output") {
                    HStack {
                        TextField("Output file", text: $outputPath)
                        Button("Save As…") { chooseOutput() }
                    }
                }
            }

            HStack {
                Button {
                    runImport()
                } label: {
                    if isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Load Highlights")
                    }
                }
                .disabled(isRunning || inputPath.isEmpty || outputPath.isEmpty)

                if let count = lastExportCount {
                    Text("\(count) highlight\(count == 1 ? "" : "s") loaded")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }

            Table(displayedHighlights, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Title", value: \.title)
                TableColumn("Author", value: \.author)
                TableColumn("Date", value: \.date)
                TableColumn("Text", value: \.text) { highlight in
                    Text(highlight.text)
                        .lineLimit(2)
                }
            }
            .onHover { isHoveringTable = $0 }
            .contextMenu(forSelectionType: Highlight.ID.self) { ids in
                Button("Copy Text") { copyText(for: ids) }
                Button("Open") { openDetail(for: ids) }
            }
        }
        .padding()
        .searchable(text: $searchText, prompt: "Filter highlights")
        .frame(minWidth: 720, minHeight: 480)
        .onChange(of: highlights) { _, _ in refreshDisplayedHighlights() }
        .onChange(of: searchText) { _, _ in refreshDisplayedHighlights() }
        .onChange(of: sortOrder) { _, _ in refreshDisplayedHighlights() }
        .onAppear { installDoubleClickMonitor() }
        .onDisappear { removeDoubleClickMonitor() }
    }

    // Table cells can't carry a click/double-click gesture of their own without
    // stealing the click from Table's native row-selection hit testing (a
    // gesture's hit area is the view's tight bounds — e.g. just the text
    // glyphs — leaving "dead zones" over text where the row wouldn't select).
    // Detecting double-clicks via a non-consuming NSEvent monitor instead
    // means the click always reaches Table normally; we just react to it.
    private func installDoubleClickMonitor() {
        doubleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            if event.clickCount == 2, isHoveringTable, let id = selection,
               let highlight = displayedHighlights.first(where: { $0.id == id }) {
                openDetail(highlight)
            }
            return event
        }
    }

    private func removeDoubleClickMonitor() {
        if let monitor = doubleClickMonitor {
            NSEvent.removeMonitor(monitor)
            doubleClickMonitor = nil
        }
    }

    private func refreshDisplayedHighlights() {
        let filtered: [Highlight]
        if searchText.isEmpty {
            filtered = highlights
        } else {
            let needle = searchText.lowercased()
            filtered = highlights.filter {
                $0.title.lowercased().contains(needle)
                    || $0.author.lowercased().contains(needle)
                    || $0.text.lowercased().contains(needle)
            }
        }
        displayedHighlights = filtered.sorted(using: sortOrder)
    }

    private static func defaultOutputPath(for device: DeviceType) -> String {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        let appDir = caches.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Stitch", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(device.defaultOutputName).path
    }

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: inputPath).deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            inputPath = url.path
        }
    }

    private func chooseOutput() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = URL(fileURLWithPath: outputPath).lastPathComponent
        panel.directoryURL = URL(fileURLWithPath: outputPath).deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }

    private func runImport() {
        errorMessage = nil
        isRunning = true
        let device = device
        let inputPath = inputPath
        let outputPath = outputPath

        Task {
            defer { isRunning = false }
            do {
                let results = try await StitchBridge.export(device: device, inputPath: inputPath, outputPath: outputPath)
                highlights = results
                lastExportCount = results.count
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openDetail(_ highlight: Highlight) {
        DetailWindowManager.shared.open(highlight: highlight)
    }

    private func openDetail(for ids: Set<Highlight.ID>) {
        for highlight in highlights where ids.contains(highlight.id) {
            openDetail(highlight)
        }
    }

    private func copyText(for ids: Set<Highlight.ID>) {
        let text = highlights
            .filter { ids.contains($0.id) }
            .map(\.text)
            .joined(separator: "\n\n")
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    ContentView()
}
