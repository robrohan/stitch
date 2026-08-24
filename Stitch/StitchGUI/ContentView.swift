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

    var filteredHighlights: [Highlight] {
        guard !searchText.isEmpty else { return highlights }
        let needle = searchText.lowercased()
        return highlights.filter {
            $0.title.lowercased().contains(needle)
                || $0.author.lowercased().contains(needle)
                || $0.text.lowercased().contains(needle)
        }
    }

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
                    runExport()
                } label: {
                    if isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Export")
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

            Table(filteredHighlights) {
                TableColumn("Title", value: \.title)
                TableColumn("Author", value: \.author)
                TableColumn("Date", value: \.date)
                TableColumn("Text") { highlight in
                    Text(highlight.text)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .searchable(text: $searchText, prompt: "Filter highlights")
        .frame(minWidth: 720, minHeight: 480)
    }

    private static func defaultOutputPath(for device: DeviceType) -> String {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return downloads.appendingPathComponent(device.defaultOutputName).path
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

    private func runExport() {
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
}

#Preview {
    ContentView()
}
