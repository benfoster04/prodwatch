import Foundation

// MARK: - Section
/// A single timed unit within a show (e.g. "Act 1", "Interval", "Band Tune")
struct ShowSection: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    var name: String
    var targetDuration: TimeInterval?    // optional target in seconds
    var notes: String = ""
    var recordedDuration: TimeInterval?  // filled in after the section runs
    var sectionType: SectionType = .primary
}

enum SectionType: String, Codable, CaseIterable {
    case primary   = "Primary"
    case timestamp = "Timestamp"
}

// MARK: - Act
/// A named grouping of sections (e.g. "First Half", or a flat show can have one act)
struct Act: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    var name: String
    var sections: [ShowSection] = []
}

// MARK: - Show
/// The top-level show document — saved/loaded as a .prodwatch JSON file
struct Show: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var venue: String = ""
    var date: Date = Date()
    var acts: [Act] = []

    /// Flattened list of all sections across all acts — useful for linear navigation
    var allSections: [ShowSection] {
        acts.flatMap { $0.sections }
    }
}

// MARK: - Timestamp Log Entry
/// A single logged event during a live show run
struct TimestampEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var sectionName: String
    var actName: String
    var event: TimestampEvent
    var wallClockTime: Date         // real time of day
    var showElapsed: TimeInterval   // seconds since show start
    var duration: TimeInterval?     // populated for pause/stop durations
    var resumedFromSection: String? // populated for showResumed events
}

enum TimestampEvent: String, Codable {
    case started            = "Started"
    case stopped            = "Stopped"
    case reset              = "Reset"
    case completed          = "Completed"
    case timestamp          = "Timestamp"
    case showCompleted      = "Show Completed"

    // Pause tracking
    case paused             = "Paused"
    case resumedFromPause   = "Resumed from Pause"

    // Show stop
    case showStopped        = "Show Stopped"
    case showResumed        = "Show Resumed"
    case showCancelled      = "Show Cancelled"
}

// MARK: - Show Stop Resolution
/// The three possible outcomes when a show stop is resolved
enum ShowStopResolution {
    case resumeFromCurrent
    case resumeFromSection(actIndex: Int, sectionIndex: Int)
    case cancelShow
}

// MARK: - Show Run
/// A live run of a show — holds all timestamp logs for export
struct ShowRun: Identifiable, Codable {
    var id: UUID = UUID()
    var show: Show
    var startedAt: Date = Date()
    var endedAt: Date? = nil
    var wasCancelled: Bool = false
    var entries: [TimestampEntry] = []

    /// Total elapsed time from first start to last stop
    var totalDuration: TimeInterval {
        guard let first = entries.first, let last = entries.last else { return 0 }
        return last.wallClockTime.timeIntervalSince(first.wallClockTime)
    }
}
