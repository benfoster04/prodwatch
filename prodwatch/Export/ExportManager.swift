import Foundation
import PDFKit
import AppKit
import UniformTypeIdentifiers

// MARK: - ExportManager
/// Handles exporting a ShowRun to .txt, .json, and .pdf formats.
enum ExportManager {

    // MARK: - Public Entry Points

    /// Present a save panel and export in the chosen format
    static func export(_ run: ShowRun, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.title = "Export Show Report"
        panel.nameFieldStringValue = fileName(for: run, format: format)
        panel.allowedContentTypes = [format.utType]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportPath(run, format: format, path: url)
    }
    
    static func exportPath(_ run: ShowRun, format: ExportFormat, path: URL) {
        print("[Export] Path: \(path)")
        do {
            switch format {
            case .txt:  try exportTXT(run, to: path)
            case .json: try exportJSON(run, to: path)
            case .pdf:  try exportPDF(run, to: path)
            }
        } catch {
            print("[Export] Failed: \(error)")
        }
    }

    // MARK: - TXT

    private static func exportTXT(_ run: ShowRun, to url: URL) throws {
        var lines: [String] = []

        lines.append("SHOW REPORT")
        lines.append(String(repeating: "=", count: 50))
        lines.append("Show:    \(run.show.title)")
        lines.append("Venue:   \(run.show.venue.isEmpty ? "—" : run.show.venue)")
        lines.append("Date:    \(run.show.date.formatted(date: .long, time: .omitted))")
        lines.append("Started: \(run.startedAt.formatted(date: .omitted, time: .standard))")
        if let ended = run.endedAt {
            lines.append("Ended:   \(ended.formatted(date: .omitted, time: .standard))")
        }
        lines.append("Status:  \(run.wasCancelled ? "CANCELLED" : "Completed")")
        lines.append(String(repeating: "=", count: 50))
        lines.append("")
        lines.append("TIMESTAMP LOG")
        lines.append(String(repeating: "-", count: 50))

        for entry in run.entries {
            let wallTime  = entry.wallClockTime.formatted(date: .omitted, time: .standard)
            let showTime  = entry.showElapsed.stopwatchFormatted
            var line = "[\(wallTime)]  +\(showTime)  \(entry.actName) › \(entry.sectionName)  —  \(entry.event.rawValue)"
            if let dur = entry.duration {
                line += "  (\(dur.stopwatchFormatted))"
            }
            if let resumed = entry.resumedFromSection {
                line += "  → \(resumed)"
            }
            lines.append(line)
        }

        lines.append("")
        lines.append(String(repeating: "-", count: 50))
        lines.append("Total show duration: \(run.totalDuration.stopwatchFormatted)")

        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - JSON

    private static func exportJSON(_ run: ShowRun, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(run)
        try data.write(to: url)
    }

    // MARK: - PDF

    private static func exportPDF(_ run: ShowRun, to url: URL) throws {
        let renderer = PDFReportRenderer(run: run)
        let data = renderer.render()
        try data.write(to: url)
    }

    // MARK: - Helpers
    public static func fileName(for run: ShowRun, format: ExportFormat) -> String {
        let title = run.show.title
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let date = run.startedAt.formatted(.iso8601.year().month().day())
        return "\(title)_\(date).\(format.rawValue)"
    }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable {
    case txt  = "txt"
    case json = "json"
    case pdf  = "pdf"

    var label: String {
        switch self {
        case .txt:  return "Plain Text (.txt)"
        case .json: return "JSON (.json)"
        case .pdf:  return "PDF Report (.pdf)"
        }
    }

    var utType: UTType {
        switch self {
        case .txt:  return .plainText
        case .json: return .json
        case .pdf:  return .pdf
        }
    }
}

// MARK: - PDF Renderer
/// Builds a formatted PDF report using Core Graphics
private struct PDFReportRenderer {
    let run: ShowRun

    func render() -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
              let ctx = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return data as Data
        }

        ctx.beginPDFPage(nil)

        let margin: CGFloat = 50
        var y = pageRect.height - margin

        // Title block
        y = drawText(ctx, text: "SHOW REPORT",
                     x: margin, y: y, width: pageRect.width - margin * 2,
                     font: .boldSystemFont(ofSize: 18), color: .black)
        y -= 6
        y = drawRule(ctx, x: margin, y: y, width: pageRect.width - margin * 2)
        y -= 10

        // Show metadata
        let meta: [(String, String)] = [
            ("Show",    run.show.title),
            ("Venue",   run.show.venue.isEmpty ? "—" : run.show.venue),
            ("Date",    run.show.date.formatted(date: .long, time: .omitted)),
            ("Started", run.startedAt.formatted(date: .omitted, time: .standard)),
            ("Status",  run.wasCancelled ? "CANCELLED" : "Completed"),
            ("Total Duration", run.totalDuration.stopwatchFormatted)
        ]

        for (label, value) in meta {
            y = drawLabelValue(ctx, label: label, value: value,
                               x: margin, y: y, width: pageRect.width - margin * 2)
            y -= 4
        }

        y -= 12
        y = drawText(ctx, text: "TIMESTAMP LOG",
                     x: margin, y: y, width: pageRect.width - margin * 2,
                     font: .boldSystemFont(ofSize: 12), color: .black)
        y -= 4
        y = drawRule(ctx, x: margin, y: y, width: pageRect.width - margin * 2)
        y -= 8

        // Log entries
        for entry in run.entries {
            let wallTime = entry.wallClockTime.formatted(date: .omitted, time: .standard)
            let showTime = entry.showElapsed.stopwatchFormatted
            var text = "[\(wallTime)]  +\(showTime)  \(entry.actName) › \(entry.sectionName)  —  \(entry.event.rawValue)"
            if let dur = entry.duration {
                text += "  (\(dur.stopwatchFormatted))"
            }
            if let resumed = entry.resumedFromSection {
                text += "  → \(resumed)"
            }

            // New page if needed
            if y < margin + 40 {
                ctx.endPDFPage()
                ctx.beginPDFPage(nil)
                y = pageRect.height - margin
            }

            y = drawText(ctx, text: text,
                         x: margin, y: y, width: pageRect.width - margin * 2,
                         font: .monospacedSystemFont(ofSize: 9, weight: .regular),
                         color: colorForEvent(entry.event))
            y -= 3
        }

        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    // MARK: Drawing Helpers

    @discardableResult
    private func drawText(_ ctx: CGContext, text: String, x: CGFloat, y: CGFloat,
                          width: CGFloat, font: NSFont, color: NSColor) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(str)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRangeMake(0, 0),
            nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil)

        let rect = CGRect(x: x, y: y - size.height, width: width, height: size.height)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, ctx)
        return y - size.height
    }

    @discardableResult
    private func drawRule(_ ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + width, y: y))
        ctx.strokePath()
        return y - 1
    }

    @discardableResult
    private func drawLabelValue(_ ctx: CGContext, label: String, value: String,
                                x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let newY = drawText(ctx, text: label.uppercased(),
                            x: x, y: y, width: 100,
                            font: .boldSystemFont(ofSize: 9),
                            color: .black)
        drawText(ctx, text: value,
                 x: x + 110, y: y, width: width - 110,
                 font: .systemFont(ofSize: 10),
                 color: .black)
        return newY
    }

    private func colorForEvent(_ event: TimestampEvent) -> NSColor {
        switch event {
        case .started, .resumedFromPause, .showResumed: return NSColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1)
        case .stopped, .paused:                          return NSColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 1)
        case .showStopped, .showCancelled:               return NSColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1)
        case .timestamp:                                 return NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1)
        case .showCompleted:                             return NSColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1)
        case .reset, .completed:                         return .black
        }
    }
}
