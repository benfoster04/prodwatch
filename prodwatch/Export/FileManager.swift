import AppKit
import UniformTypeIdentifiers

func saveShow(show: Show) {
    let panel = NSSavePanel()
    panel.title = "Save Show"
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "\(show.title.replacingOccurrences(of: " ", with: "_")).prodwatch"

    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(show)
        try data.write(to: url)
    } catch {
        print("[Save] Failed: \(error)")
    }
}

func openShow() -> Show? {
    let panel = NSOpenPanel()
    panel.title = "Open Show"
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let url = panel.url else { return .none }

    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(Show.self, from: data)
        return loaded
    } catch {
        print("[Open] Failed: \(error)")
        return .none
    }
}
