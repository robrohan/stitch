import Foundation

enum DeviceType: String, CaseIterable, Identifiable {
    case kindle = "Kindle"
    case kobo = "Kobo"

    var id: String { rawValue }

    // Mirrors README.md's documented Mac defaults / env vars.
    var defaultInputPath: String {
        let env = ProcessInfo.processInfo.environment
        switch self {
        case .kindle:
            return env["STITCH_KINDLE"] ?? "/Volumes/Kindle/documents/My Clippings.txt"
        case .kobo:
            return env["STITCH_KOBO"] ?? "/Volumes/KOBOeReader/.kobo/KoboReader.sqlite"
        }
    }

    var defaultOutputName: String {
        switch self {
        case .kindle: return "kindle.json"
        case .kobo: return "kobo.json"
        }
    }
}

enum StitchError: LocalizedError {
    case inputNotAccessible(String)
    case exportFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .inputNotAccessible(let path):
            return "Could not access input file: \(path)"
        case .exportFailed(let code):
            return "Export failed (code \(code))"
        }
    }
}

enum StitchBridge {
    /// Runs the C export (src/stitch_api.h) off the main thread, then loads
    /// the resulting JSON back in.
    static func export(device: DeviceType, inputPath: String, outputPath: String) async throws -> [Highlight] {
        let code: Int32 = await Task.detached(priority: .userInitiated) {
            inputPath.withCString { inputC in
                outputPath.withCString { outputC in
                    switch device {
                    case .kindle:
                        return stitch_export_kindle(inputC, outputC)
                    case .kobo:
                        return stitch_export_kobo(inputC, outputC)
                    }
                }
            }
        }.value

        switch code {
        case 0:
            break
        case 2:
            throw StitchError.inputNotAccessible(inputPath)
        default:
            throw StitchError.exportFailed(code)
        }

        return try Highlight.load(fromFile: URL(fileURLWithPath: outputPath))
    }
}
