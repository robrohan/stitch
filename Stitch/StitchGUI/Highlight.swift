import Foundation

struct Highlight: Identifiable {
    let id: String
    let type: String
    let deviceType: String
    let isbn: String
    let title: String
    let author: String
    let page: Int
    let startOffset: Int
    let endOffset: Int
    let date: String
    let text: String
    let annotation: String
    let annotationExtra: String

    // The exporter always terminates the JSON array with a trailing `{}`
    // sentinel (see kobo.c / kindle.c) to avoid trailing-comma handling.
    // Decode leniently via JSONSerialization and drop empty entries instead
    // of failing a strict Codable decode.
    static func load(fromFile url: URL) throws -> [Highlight] {
        let data = try Data(contentsOf: url)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dict in
            guard let text = dict["text"] as? String, !text.isEmpty else { return nil }
            return Highlight(
                id: dict["id"] as? String ?? UUID().uuidString,
                type: dict["type"] as? String ?? "",
                deviceType: dict["deviceType"] as? String ?? "",
                isbn: dict["isbn"] as? String ?? "",
                title: dict["title"] as? String ?? "",
                author: dict["author"] as? String ?? "",
                page: dict["page"] as? Int ?? 0,
                startOffset: dict["startOffset"] as? Int ?? 0,
                endOffset: dict["endOffset"] as? Int ?? 0,
                date: dict["date"] as? String ?? "",
                text: text,
                annotation: dict["annotation"] as? String ?? "",
                annotationExtra: dict["annotationExtra"] as? String ?? ""
            )
        }
    }
}
