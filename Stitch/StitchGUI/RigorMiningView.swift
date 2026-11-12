import SwiftUI
import AppKit

struct RigorMiningView: View {
    @State private var server: String = RigorMiningConfig.load()?.server ?? ""
    @State private var token: String = RigorMiningConfig.load()?.token ?? ""
    @State private var signedInAs: String?

    @State private var koboDir: String = RigorMiningClient.findKobo() ?? "/Volumes/KOBOeReader"
    @State private var dryRun = false

    @State private var items: [RMItem] = []
    @State private var showingSearchResults = false
    @State private var query: String = ""
    @State private var selection: RMItem.ID?

    @State private var log: [String] = []
    @State private var isRunning = false
    @State private var errorMessage: String?

    private var client: RigorMiningClient {
        RigorMiningClient(config: RigorMiningConfig(server: server, token: token))
    }

    private var isConfigured: Bool { !server.isEmpty && !token.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                LabeledContent("Server") {
                    TextField("https://your-server.example.com", text: $server)
                }

                LabeledContent("API Token") {
                    HStack {
                        SecureField("Created on the app's Settings page", text: $token)
                        Button("Connect") { connect() }
                            .disabled(isRunning || !isConfigured)
                    }
                }

                LabeledContent("Kobo") {
                    HStack {
                        TextField("Mounted Kobo root", text: $koboDir)
                        Button("Detect") { detectKobo() }
                        Button("Choose…") { chooseKobo() }
                    }
                }
            }

            HStack {
                Button {
                    runSync()
                } label: {
                    if isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(dryRun ? "Preview Sync" : "Sync to Kobo")
                    }
                }
                .disabled(isRunning || !isConfigured || koboDir.isEmpty)

                Toggle("Dry run", isOn: $dryRun)

                if let signedInAs {
                    Text("Signed in as \(signedInAs)")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .help(errorMessage)
                }
            }

            HStack {
                TextField("Find items to queue", text: $query)
                    .onSubmit { search() }
                Button("Search") { search() }
                    .disabled(isRunning || !isConfigured || query.isEmpty)
                Button("Show Queue") { refreshQueue() }
                    .disabled(isRunning || !isConfigured)
            }

            Text(showingSearchResults ? "Search results" : "Queued for, or already on, the Kobo")
                .font(.caption)
                .foregroundStyle(.secondary)

            Table(items, selection: $selection) {
                TableColumn("Title") { item in Text(item.title) }
                TableColumn("State") { item in
                    Text(Self.label(for: item.syncState))
                        .foregroundStyle(.secondary)
                }
                .width(min: 120, ideal: 140, max: 180)
            }
            .overlay {
                if items.isEmpty && !isRunning {
                    Text(showingSearchResults ? "No matches" : "Nothing queued or on the Kobo")
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu(forSelectionType: RMItem.ID.self) { ids in
                Button("Queue for Kobo") { change(ids, queue: true) }
                Button("Un-queue / Remove from Kobo") { change(ids, queue: false) }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(log.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
                .frame(height: 120)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                .onChange(of: log.count) { _, count in
                    if count > 0 { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
        }
        .padding()
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            if isConfigured && items.isEmpty { refreshQueue() }
        }
    }

    private static func label(for state: String?) -> String {
        switch state.flatMap(SyncState.init(rawValue:)) {
        case .requestSync: return "Waiting to copy"
        case .requestRemove: return "Waiting to remove"
        case .synced: return "On Kobo"
        case nil: return state ?? "Not queued"
        }
    }

    /// Runs one piece of work with the shared busy/error state.
    private func perform(_ work: @escaping @MainActor () async throws -> Void) {
        errorMessage = nil
        isRunning = true
        Task {
            defer { isRunning = false }
            do {
                try await work()
            } catch {
                errorMessage = error.localizedDescription
                log.append("Error: \(error.localizedDescription)")
            }
        }
    }

    /// Validates the token against /whoami before saving it, like the
    /// skill's `configure` command.
    private func connect() {
        let client = client
        perform {
            let email = try await client.whoami()
            try client.config.save()
            signedInAs = email
            log.append("Saved config to \(RigorMiningConfig.defaultURL.path) - signed in as \(email).")
            items = try await loadQueue(client)
            showingSearchResults = false
        }
    }

    private func refreshQueue() {
        let client = client
        perform {
            items = try await loadQueue(client)
            showingSearchResults = false
        }
    }

    private func loadQueue(_ client: RigorMiningClient) async throws -> [RMItem] {
        let toSync = try await client.items(syncState: .requestSync)
        let toRemove = try await client.items(syncState: .requestRemove)
        let synced = try await client.items(syncState: .synced)
        log.append("Queue: \(toSync.count) to copy, \(toRemove.count) to remove, \(synced.count) on the Kobo.")
        return toSync + toRemove + synced
    }

    private func search() {
        guard !query.isEmpty else { return }
        let client = client
        let query = query
        perform {
            items = try await client.items(query: query)
            showingSearchResults = true
            log.append("Search \"\(query)\": \(items.count) match\(items.count == 1 ? "" : "es").")
        }
    }

    private func change(_ ids: Set<RMItem.ID>, queue: Bool) {
        let client = client
        let targets = items.filter { ids.contains($0.id) }
        perform {
            for target in targets {
                let updated: RMItem?
                if queue {
                    updated = try await client.queue(target)
                } else {
                    updated = try await client.unqueue(target)
                }
                guard let updated else { continue }
                log.append("\(queue ? "Queued" : "Un-queued"): \(updated.title) (\(Self.label(for: updated.syncState)))")
                if let index = items.firstIndex(where: { $0.id == updated.id }) {
                    items[index] = updated
                }
            }
        }
    }

    private func runSync() {
        let client = client
        let koboDir = koboDir
        let dryRun = dryRun
        log.append(dryRun ? "--- Preview of sync to \(koboDir)" : "--- Syncing to \(koboDir)")
        perform {
            let summary = try await client.run(koboDir: koboDir, dryRun: dryRun) { line in
                await MainActor.run { log.append(line) }
            }
            log.append(summary.description)
            items = try await loadQueue(client)
            showingSearchResults = false
        }
    }

    private func detectKobo() {
        if let found = RigorMiningClient.findKobo() {
            koboDir = found
            errorMessage = nil
        } else {
            errorMessage = "No mounted Kobo found - choose its folder instead."
        }
    }

    private func chooseKobo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        if panel.runModal() == .OK, let url = panel.url {
            koboDir = url.path
        }
    }
}

#Preview {
    RigorMiningView()
}
