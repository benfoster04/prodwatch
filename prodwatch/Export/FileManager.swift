import AppKit
import SwiftUI
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
    } catch EncodingError.invalidValue(let a, let context) {
        print("[Save] Invalid Value")
        print(a)
        print(context)
    } catch {
        print("[Save] Failed: \(error)")
    }
}

enum ShowFileError: LocalizedError {
    case DataCorrupted (DecodingError.Context)
    case KeyNotFound (CodingKey, DecodingError.Context)
    case TypeMismatch (Any.Type, DecodingError.Context)
    case ValueNotFound (Any.Type, DecodingError.Context)
    case Unknown (String)
    
    var errorDescription: String? {
        switch self {
        case .DataCorrupted(_): return "File corrupted."
        case .KeyNotFound(let k, _): return "Missing key in json structure: \(k.stringValue)"
        case .TypeMismatch(let t, _): return "Type mismatch: \(t)"
        case .ValueNotFound(let t, _): return "Value not found: \(t)"
        case .Unknown(let str): return str
        }
    }
    
    var failureReason: String? {
        switch self {
        case .DataCorrupted(let ctx): return ctx.debugDescription
        case .KeyNotFound(_, let ctx): return ctx.debugDescription
        case .TypeMismatch(_, let ctx): return ctx.debugDescription
        case .ValueNotFound(_, let ctx): return ctx.debugDescription
        case .Unknown(_): return nil
        }
    }
    
    var helpAnchor: String? {
        nil
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .DataCorrupted(let ctx): ctx.underlyingError?.localizedDescription
        case .KeyNotFound(let k, _): "We tried looking for \(k), but it doesn't exist. Check your file contents."
        case .TypeMismatch(let t, _): "Something's wrong with your file. \(t)"
        case .ValueNotFound(let t, _): "Something's wrong with your file. \(t)"
        case .Unknown(_): "Sorry, we don't know what happened there."
        }
    }
}

func openShow(engine: TimerEngine) -> Show? {
    
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
        
    } catch DecodingError.dataCorrupted(let context) {
        print("[Open] Data Corrupted")
        print(context)
        engine.error = ShowFileError.DataCorrupted(context)
        
    } catch DecodingError.keyNotFound(let k, let context) {
        print("[Open] Key Not Found")
        print(k)
        print(context)
        engine.error = ShowFileError.KeyNotFound(k, context)
        
    } catch DecodingError.typeMismatch(let t, let context) {
        print("[Open] Type Mismatch")
        print(t)
        print(context)
        engine.error = ShowFileError.TypeMismatch(t, context)
        
    } catch DecodingError.valueNotFound(let t, let context) {
        print("[Open] Value Not Found")
        print(t)
        print(context)
        engine.error = ShowFileError.ValueNotFound(t, context)
        
    } catch {
        print("[Open] Failed: \(error)")
        engine.error = ShowFileError.Unknown(error.localizedDescription)
    }
    return .none
}
