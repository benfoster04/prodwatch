import Foundation
import SwiftUI
import Combine

// MARK: - TimerEngine
@MainActor
final class TimerEngine: ObservableObject {

    // MARK: - Published State

    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var isShowStopped: Bool = false
    @Published var isShowCancelled: Bool = false

    @Published var sectionElapsed: TimeInterval = 0    // current section stopwatch
    @Published var showElapsed: TimeInterval = 0       // global show timer
    @Published var pauseElapsed: TimeInterval = 0      // how long currently paused
    @Published var showStopElapsed: TimeInterval = 0   // how long show has been stopped

    @Published var currentSectionIndex: Int = 0
    @Published var currentActIndex: Int = 0
    @Published var showRun: ShowRun?

    // MARK: - Private

    private var ticker: AnyCancellable?
    private var sectionStart: Date?
    private var showStart: Date?
    private var pauseStart: Date?
    private var showStopStart: Date?

    private var sectionAccumulated: TimeInterval = 0
    private var showAccumulated: TimeInterval = 0
    
    @AppStorage("defaultSavePath") private var defaultSavePath: URL = URL(string: "~/Documents")!
    @AppStorage("defaultSaveType") private var defaultSaveType: ExportFormat = .pdf

    // MARK: - Setup
    func loadShow(_ show: Show) {
        ticker?.cancel()
        showRun = ShowRun(show: show)
        isRunning = false
        isPaused = false
        isShowStopped = false
        isShowCancelled = false
        sectionElapsed = 0
        showElapsed = 0
        pauseElapsed = 0
        showStopElapsed = 0
        sectionAccumulated = 0
        showAccumulated = 0
        sectionStart = nil
        showStart = nil
        pauseStart = nil
        showStopStart = nil
        currentActIndex = 0
        currentSectionIndex = 0
    }

    // MARK: - Primary Controls
    func start() {
        guard !isRunning, !isShowStopped, !isShowCancelled else { return }
        let now = Date()

        if isPaused {
            // Resuming from a pause — log pause duration
            let pauseDuration = pauseStart.map { now.timeIntervalSince($0) } ?? 0
            pauseStart = nil
            isPaused = false
            pauseElapsed = 0
            logEvent(.resumedFromPause, duration: pauseDuration)
        }

        if showStart == nil {
            showStart = now
            showRun?.startedAt = now
        }

        sectionStart = now
        isRunning = true
        logEvent(.started)
        startTick()
    }

    /// Regular pause — section timer stops, pause timer starts
    func stop() {
        guard isRunning else { return }
        let now = Date()
        isRunning = false
        isPaused = true

        if let s = sectionStart {
            sectionAccumulated += now.timeIntervalSince(s)
        }
        if let s = showStart {
            showAccumulated += now.timeIntervalSince(s)
            showStart = nil
        }

        sectionStart = nil
        pauseStart = now
        ticker?.cancel()
        logEvent(.paused)
        startTick() // keep ticking for pause counter
    }

    func reset() {
        guard !isRunning else { return }
        let wasRunning = isRunning || isPaused
        isRunning = false
        isPaused = false
        ticker?.cancel()
        sectionElapsed = 0
        sectionAccumulated = 0
        pauseElapsed = 0
        sectionStart = nil
        pauseStart = nil
        if wasRunning { logEvent(.reset) }
    }
    
    func save() {
        guard !isShowStopped, !isShowStopped else { return }
        if (showRun != nil) {
            ExportManager.exportPath(
                showRun.unsafelyUnwrapped,
                format: defaultSaveType,
                path: defaultSavePath.appending(component:
                    ExportManager.fileName(for: showRun.unsafelyUnwrapped, format: defaultSaveType)
                )
            )
        }
    }

    // MARK: - Show Stop

    /// Full show stop — halts everything and starts the show stop counter
    func showStop() {
        guard !isShowCancelled else { return }
        let now = Date()

        if isRunning {
            if let s = sectionStart { sectionAccumulated += now.timeIntervalSince(s) }
            if let s = showStart { showAccumulated += now.timeIntervalSince(s); showStart = nil }
            sectionStart = nil
        }

        isRunning = false
        isPaused = false
        isShowStopped = true
        pauseStart = nil
        pauseElapsed = 0
        showStopStart = now
        ticker?.cancel()
        logEvent(.showStopped)
        startTick() // keep ticking for show stop counter
    }

    /// Resolve a show stop — resume from a section or cancel the show
    func resolveShowStop(_ resolution: ShowStopResolution) {
        guard isShowStopped else { return }
        let now = Date()
        let stopDuration = showStopStart.map { now.timeIntervalSince($0) } ?? 0
        showStopStart = nil
        showStopElapsed = 0
        isShowStopped = false

        switch resolution {
        case .resumeFromCurrent:
            logEvent(.showResumed, duration: stopDuration,
                     resumedFromSection: currentSection?.name)
            start()

        case .resumeFromSection(let actIdx, let sectionIdx):
            currentActIndex = actIdx
            currentSectionIndex = sectionIdx
            sectionAccumulated = 0
            sectionElapsed = 0
            logEvent(.showResumed, duration: stopDuration,
                     resumedFromSection: currentSection?.name)
            start()

        case .cancelShow:
            isShowCancelled = true
            ticker?.cancel()
            showRun?.wasCancelled = true
            showRun?.endedAt = now
            logEvent(.showCancelled, duration: stopDuration)
        }
    }

    // MARK: - Section Navigation

    func nextSection() {
        guard let run = showRun else { return }
        let acts = run.show.acts
        guard currentActIndex < acts.count else { return }
        logEvent(.completed)

        if currentSectionIndex < acts[currentActIndex].sections.count - 1 {
            currentSectionIndex += 1
        } else if currentActIndex < acts.count - 1 {
            currentActIndex += 1
            currentSectionIndex = 0
        }
        resetSection()
    }

    func previousSection() {
        logEvent(.reset)
        if currentSectionIndex > 0 {
            currentSectionIndex -= 1
        } else if currentActIndex > 0 {
            currentActIndex -= 1
            let prevSections = showRun?.show.acts[currentActIndex].sections ?? []
            currentSectionIndex = max(0, prevSections.count - 1)
        }
        resetSection()
    }

    // MARK: - Go
    /// Single sequential advance — behaviour depends on the next item's type.
    /// Timestamp markers: log and advance, keep primary timer running.
    /// Primary markers: complete current, stop timer, advance, auto-start.
    func go() {
        guard !isShowStopped, !isShowCancelled else { return }
        guard let run = showRun else { return }

        let acts = run.show.acts
        guard currentActIndex < acts.count else { return }

        // Find the next item in sequence
        let nextIndices = nextSectionIndices()

//         Only log completed if current item is a primary marker
//        if currentSection?.sectionType == .primary {
//            logEvent(.completed)
//        }

        // Advance to next
        if let (nextAct, nextSection) = nextIndices {
            currentActIndex = nextAct
            currentSectionIndex = nextSection

            let next = run.show.acts[nextAct].sections[nextSection]

            switch next.sectionType {
            case .timestamp:
                // Log the timestamp marker immediately, keep timer running
                logEvent(.timestamp)

            case .primary:
                // Stop current timer, reset section, auto-start next
                isRunning = false
                ticker?.cancel()
                sectionAccumulated = 0
                sectionElapsed = 0
                sectionStart = Date()
                isRunning = true
                startTick()
                logEvent(.started)
            }
        } else {
            // End of show — halt cleanly without triggering pause state
            isRunning = false
            ticker?.cancel()
            if let s = sectionStart {
                sectionAccumulated += Date().timeIntervalSince(s)
            }
            if let s = showStart {
                showAccumulated += Date().timeIntervalSince(s)
                showStart = nil
            }
            sectionStart = nil
            showRun?.endedAt = Date()
            logEvent(.showCompleted)
        }
    }

    /// Returns the (actIndex, sectionIndex) of the next item, or nil if end of show
    
    private func nextSectionIndices() -> (Int, Int)? {
        guard let run = showRun else { return nil }
        let acts = run.show.acts
        let sections = acts[currentActIndex].sections

        if currentSectionIndex < sections.count - 1 {
            return (currentActIndex, currentSectionIndex + 1)
        } else if currentActIndex < acts.count - 1 {
            return (currentActIndex + 1, 0)
        }
        return nil
    }
    
    // MARK: - Computed Properties

    var currentSection: ShowSection? {
        guard let run = showRun,
              currentActIndex < run.show.acts.count else { return nil }
        let sections = run.show.acts[currentActIndex].sections
        guard currentSectionIndex < sections.count else { return nil }
        return sections[currentSectionIndex]
    }

    var currentAct: Act? {
        guard let run = showRun,
              currentActIndex < run.show.acts.count else { return nil }
        return run.show.acts[currentActIndex]
    }

    var targetDelta: TimeInterval? {
        guard let target = currentSection?.targetDuration else { return nil }
        return sectionElapsed - target
    }

    // MARK: - Private Helpers

    private func startTick() {
        ticker = Timer.publish(every: 0.01, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let now = Date()
                if let s = self.sectionStart {
                    self.sectionElapsed = self.sectionAccumulated + now.timeIntervalSince(s)
                }
                if let s = self.showStart {
                    self.showElapsed = self.showAccumulated + now.timeIntervalSince(s)
                }
                if let s = self.pauseStart {
                    self.pauseElapsed = now.timeIntervalSince(s)
                }
                if let s = self.showStopStart {
                    self.showStopElapsed = now.timeIntervalSince(s)
                }
            }
    }

    private func resetSection() {
        let wasRunning = isRunning
        isRunning = false
        ticker?.cancel()
        sectionElapsed = 0
        sectionAccumulated = 0
        sectionStart = nil

        if wasRunning {
            sectionStart = Date()
            isRunning = true
            startTick()
            logEvent(.started)
        }
    }

    private func logEvent(
        _ event: TimestampEvent,
        duration: TimeInterval? = nil,
        resumedFromSection: String? = nil
    ) {
        guard var run = showRun,
              let section = currentSection,
              let act = currentAct else { return }

        let entry = TimestampEntry(
            sectionName: section.name,
            actName: act.name,
            event: event,
            wallClockTime: Date(),
            showElapsed: showElapsed,
            duration: duration,
            resumedFromSection: resumedFromSection
        )
        run.entries.append(entry)
        showRun = run
    }
}

// MARK: - TimeInterval Formatting
extension TimeInterval {
    /// HH:MM:SS.cc
    var stopwatchFormatted: String {
        let totalCS = Int(self * 100)
        let cs = totalCS % 100
        let s  = (totalCS / 100) % 60
        let m  = (totalCS / 6000) % 60
        let h  = totalCS / 360000
        return String(format: "%02d:%02d:%02d.%02d", h, m, s, cs)
    }

    /// MM:SS normally, HH:MM:SS if over an hour
    var adaptiveFormatted: String {
        let total = Int(self)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// MM:SS
    var shortFormatted: String {
        let total = Int(self)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
