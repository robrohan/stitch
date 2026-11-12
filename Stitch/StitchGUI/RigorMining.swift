import Foundation
import CryptoKit

// Swift port of the rigormining skill's scripts/rigormining.py (`configure`,
// `find-kobo`, `search`, `queue`, `unqueue` and `run`). It reads and writes
// the same ~/.rigormining-sync.json config and the same `rigormining` folder
// on the Kobo, so the app and the skill can be used interchangeably.

struct RigorMiningConfig: Equatable {
    var server: String
    var token: String

    static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".rigormining-sync.json")

    static func load(from url: URL = defaultURL) -> RigorMiningConfig? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let server = dict["server"] as? String,
              let token = dict["token"] as? String else {
            return nil
        }
        return RigorMiningConfig(server: server, token: token)
    }

    func save(to url: URL = defaultURL) throws {
        let data = try JSONSerialization.data(withJSONObject: ["server": server, "token": token])
        try data.write(to: url, options: .atomic)
        // 0600 - owner read/write only, same as the skill.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

enum SyncState: String {
    case requestSync = "request_sync"
    case requestRemove = "request_remove"
    case synced = "synced"
}

/// One library item. Kept as the raw JSON dictionary too, because restoring
/// metadata after an upload PATCHes back whatever fields the server sent.
struct RMItem: Identifiable, Equatable {
    let id: String
    let title: String
    let syncState: String?
    let fileType: String?
    let fileHash: String?
    let raw: [String: Any]

    init?(_ dict: [String: Any]) {
        // The id may come back as a number or a string depending on the server.
        guard let rawID = dict["id"] else { return nil }
        id = "\(rawID)"
        title = dict["title"] as? String ?? ""
        syncState = (dict["sync_state"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        fileType = (dict["file_type"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        fileHash = (dict["file_hash"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        raw = dict
    }

    /// Mirrors frontend/src/components/Sync/index.tsx's sanitize(), so
    /// filenames match whichever tool (browser, skill or app) wrote them.
    var deviceFilename: String {
        "\(title).\(fileType ?? "")".replacingOccurrences(of: #"[\\/:]"#, with: "-", options: .regularExpression)
    }

    static func == (lhs: RMItem, rhs: RMItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.syncState == rhs.syncState
    }
}

enum RigorMiningError: LocalizedError {
    case notConfigured
    case badServerURL(String)
    case request(String, String)
    case koboNotMounted(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Enter a server URL and API token first."
        case .badServerURL(let url):
            return "Not a valid server URL: \(url)"
        case .request(let what, let detail):
            return "\(what) failed: \(detail)"
        case .koboNotMounted(let path):
            return "\(path) does not exist - is the Kobo actually mounted there?"
        }
    }
}

struct RigorMiningClient {
    let config: RigorMiningConfig

    // Matches the folder name the browser's Sync-to-Kobo screen and the skill use.
    static let subdirName = "rigormining"

    /// Every real Kobo has a .kobo folder at the root of its filesystem -
    /// more reliable than matching on the "KOBOeReader" volume label.
    static func findKobo() -> String? {
        let volumes = URL(fileURLWithPath: "/Volumes")
        let candidates = (try? FileManager.default.contentsOfDirectory(at: volumes, includingPropertiesForKeys: nil)) ?? []
        var isDir: ObjCBool = false
        return candidates.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent(".kobo").path, isDirectory: &isDir) && isDir.boolValue
        }?.path
    }

    // MARK: - HTTP

    private func request(_ method: String, _ path: String, body: Data? = nil,
                         contentType: String? = nil, timeout: TimeInterval = 30) async throws -> Data {
        let base = config.server.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + path) else { throw RigorMiningError.badServerURL(config.server) }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: req)
        } catch {
            throw RigorMiningError.request("\(method) \(path)", error.localizedDescription)
        }
        let (data, response) = result
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw RigorMiningError.request("\(method) \(path)", "\(http.statusCode) \(detail)")
        }
        return data
    }

    private func json(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> Any? {
        let payload = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        let data = try await request(method, path, body: payload)
        return data.isEmpty ? nil : try JSONSerialization.jsonObject(with: data)
    }

    private func item(_ method: String, _ path: String) async throws -> RMItem? {
        (try await json(method, path) as? [String: Any]).flatMap(RMItem.init)
    }

    // MARK: - API

    /// Validates the token; returns the signed-in email.
    func whoami() async throws -> String {
        let who = try await json("GET", "/api/v1/whoami") as? [String: Any]
        return who?["email"] as? String ?? "(unknown)"
    }

    func items(syncState: SyncState? = nil, query: String? = nil) async throws -> [RMItem] {
        var components = URLComponents()
        components.queryItems = []
        if let syncState { components.queryItems?.append(URLQueryItem(name: "sync_state", value: syncState.rawValue)) }
        if let query { components.queryItems?.append(URLQueryItem(name: "q", value: query)) }
        let qs = components.percentEncodedQuery.map { $0.isEmpty ? "" : "?\($0)" } ?? ""
        let path = "/api/v1/items\(qs)"
        let data = try await request("GET", path)
        guard !data.isEmpty else { return [] }
        let parsed = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        if parsed is NSNull { return [] }  // Go encodes an empty nil slice as `null`
        guard let list = parsed as? [[String: Any]] else {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw RigorMiningError.request("GET \(path)", "expected a JSON array, got: \(preview)")
        }
        return list.compactMap(RMItem.init)
    }

    func queue(_ item: RMItem) async throws -> RMItem? {
        try await self.item("POST", "/api/v1/items/\(item.id)/sync")
    }

    /// Cancels a pending sync, or requests removal if it's already on the device.
    func unqueue(_ item: RMItem) async throws -> RMItem? {
        try await self.item("DELETE", "/api/v1/items/\(item.id)/sync")
    }

    private func ack(_ item: RMItem, _ result: String) async throws {
        _ = try await json("POST", "/api/v1/items/\(item.id)/sync/ack", ["result": result])
    }

    private func downloadFile(_ item: RMItem) async throws -> Data {
        try await request("GET", "/api/v1/items/\(item.id)/file", timeout: 300)
    }

    /// True if the file on the Kobo differs from the server's copy, i.e. it
    /// was annotated on the device. Uses the server's file_hash when it
    /// sends one, otherwise downloads the server's file to compare.
    private func deviceCopyChanged(_ item: RMItem, at url: URL) async throws -> Bool {
        let deviceHash = sha256(try Data(contentsOf: url))
        let serverHash: String
        if let hash = item.fileHash {
            serverHash = hash
        } else {
            serverHash = sha256(try await downloadFile(item))
        }
        return deviceHash != serverHash
    }

    /// Uploads the device's copy back over the server's file, so notes written
    /// on the Kobo (stored inside the PDF itself) survive the device copy
    /// being deleted. Returns an error string rather than throwing - a failed
    /// upload must leave the file on the device, not abort the run.
    private func uploadAnnotated(_ item: RMItem, from url: URL, log: (String) async -> Void) async -> String? {
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"keep_metadata\"\r\n\r\ntrue\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\nContent-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        do {
            body.append(try Data(contentsOf: url))
        } catch {
            return error.localizedDescription
        }
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let updated: RMItem?
        do {
            let data = try await request("POST", "/api/v1/items/\(item.id)/file", body: body,
                                         contentType: "multipart/form-data; boundary=\(boundary)", timeout: 300)
            updated = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap(RMItem.init)
        } catch RigorMiningError.request(_, let detail) {
            return detail
        } catch {
            return error.localizedDescription
        }

        if let updated, updated.title != item.title {
            // A server without keep_metadata support renames the item from the
            // PDF's embedded title - put the original metadata back.
            var restore: [String: Any] = [:]
            for key in ["title", "authors", "doi", "isbn", "source_url", "notes",
                        "item_type", "venue", "volume", "number", "pages", "publisher"] {
                restore[key] = nonNull(item.raw[key]) ?? ""
            }
            restore["year"] = nonNull(item.raw["year"]) ?? 0
            do {
                _ = try await json("PATCH", "/api/v1/items/\(item.id)", restore)
                await log("  (server renamed it to \"\(updated.title)\" - restored; update the server to support keep_metadata)")
            } catch {
                await log("  (server renamed it to \"\(updated.title)\" and restoring the title failed: \(error.localizedDescription))")
            }
        }
        return nil
    }

    // MARK: - Sync

    struct SyncSummary {
        var copied = 0, removed = 0, uploaded = 0, kept = 0, reconciled = 0

        var description: String {
            "Done - \(copied) copied, \(removed) removed (\(uploaded) annotated copies uploaded first), "
                + "\(kept) kept on device (upload failed), \(reconciled) un-queued (already gone from the device)."
        }
    }

    /// Same steps, in the same order, as the skill's `run` command.
    func run(koboDir: String, dryRun: Bool, log: @escaping (String) async -> Void) async throws -> SyncSummary {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: koboDir, isDirectory: &isDir), isDir.boolValue else {
            throw RigorMiningError.koboNotMounted(koboDir)
        }
        let dir = URL(fileURLWithPath: koboDir).appendingPathComponent(Self.subdirName, isDirectory: true)
        if !dryRun {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var summary = SyncSummary()

        // Reconcile first: "synced" only records "we copied this at some
        // point" - if the file was deleted directly on the device, nothing
        // else would ever notice.
        for item in try await items(syncState: .synced) where item.fileType != nil {
            if !fm.fileExists(atPath: dir.appendingPathComponent(item.deviceFilename).path) {
                if dryRun {
                    await log("[dry-run] would un-queue (no longer on the device): \(item.title)")
                    continue
                }
                try await ack(item, "removed")
                summary.reconciled += 1
            }
        }
        if summary.reconciled > 0 {
            await log("\(summary.reconciled) item(s) no longer on the device - un-queued.")
        }

        // Before deleting anything, a copy that changed on the device is
        // uploaded back first. If that upload fails the file stays on the
        // device and the item stays queued, so the next run retries.
        for item in try await items(syncState: .requestRemove) {
            let target = dir.appendingPathComponent(item.deviceFilename)
            let exists = fm.fileExists(atPath: target.path)
            var changed = false
            if exists, item.fileType != nil {
                changed = try await deviceCopyChanged(item, at: target)
            }
            if dryRun {
                await log("[dry-run] would \(changed ? "upload the annotated copy of, then " : "")remove \(item.deviceFilename)")
                continue
            }
            if changed {
                if let err = await uploadAnnotated(item, from: target, log: log) {
                    summary.kept += 1
                    await log("Kept on device (upload of annotated copy failed: \(err)): \(item.title)")
                    continue
                }
                summary.uploaded += 1
                await log("Uploaded annotated copy: \(item.title)")
            }
            if exists {
                try fm.removeItem(at: target)
            }
            try await ack(item, "removed")
            summary.removed += 1
            await log("Removed: \(item.title)")
        }

        for item in try await items(syncState: .requestSync) {
            guard item.fileType != nil else {
                await log("Skipping (no file attached yet): \(item.title)")
                continue
            }
            if dryRun {
                await log("[dry-run] would copy \(item.deviceFilename)")
                continue
            }
            let data = try await downloadFile(item)
            try data.write(to: dir.appendingPathComponent(item.deviceFilename))
            try await ack(item, "synced")
            summary.copied += 1
            await log("Copied: \(item.title)")
        }

        return summary
    }

    private func nonNull(_ value: Any?) -> Any? {
        value is NSNull ? nil : value
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
