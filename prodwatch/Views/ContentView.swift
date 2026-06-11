import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView
/// Root layout — NavigationSplitView with sidebar (show structure)
/// and detail (timer display). Owns all top-level state.
struct ContentView: View {
    
    @ObservedObject var engine: TimerEngine
    @ObservedObject var oscListener: OSCListener
    
    @Environment(\.openWindow)      private var openWindow
    @Environment(\.openSettings)    private var openSettings

    @AppStorage("oscPort")          private var oscPort: Int = 53000
    @AppStorage("colorScheme")      private var colorSchemePreference: ColorSchemePreference = .system
    @AppStorage("defaultVenue")     private var defaultVenue: String = ""
    @AppStorage("showCentiseconds") private var showCentiseconds: Bool = true
    @AppStorage("autoStartOSC")     private var autoStartOSC: Bool = false

    @State private var colorSchemeID: UUID = UUID()
    @State private var showingExport    = false
    @State private var showingLog       = false
    @State private var showingNewShow   = false
    @State private var confirmNewShow   = false
    @State private var confirmOpenShow  = false
    
    func newShowDialog() { confirmNewShow     = true }
    func openShowDialog() { confirmOpenShow   = true }

    var body: some View {
        NavigationSplitView {
            SidebarView(engine: engine)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            TimerDisplayView(engine: engine)
        }
        .toolbar { toolbarContent }
        .preferredColorScheme(colorSchemePreference.colorScheme)
        .id(colorSchemeID)
        .onChange(of: colorSchemePreference) {
            if colorSchemePreference == .system {
                colorSchemeID = UUID()
            }
        }
        .sheet(isPresented: $showingNewShow) {
            NewShowView() { newShow in
                engine.loadShow(newShow)
            }
        }
        .sheet(isPresented: $showingLog) {
            LogSheetView(engine: engine)
        }
        .sheet(isPresented: $showingExport) {
            ExportSheetView(engine: engine)
        }
        .onAppear {
            if (autoStartOSC) {
                oscListener.start(port: UInt16(oscPort), onCommand: handleOSC)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .oscPortDidChange)) { note in
            guard let port = note.userInfo?["port"] as? Int else { return }
            oscListener.restart(port: UInt16(port), onCommand: handleOSC)
        }
        // Manage Show state with the engine
//        .onChange(of: show) {
//            engine.loadShow(show)
//        }
        .confirmationDialog("Start a New Show?", isPresented: $confirmNewShow, titleVisibility: .visible) {
            Button("Continue", role: .destructive) { showingNewShow = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Any unsaved changes to the current show will be lost.")
        }
        .confirmationDialog("Open a Show?", isPresented: $confirmOpenShow, titleVisibility: .visible) {
            Button("Continue", role: .destructive) {
                if let newshow = openShow() {
                    engine.loadShow(newshow)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Any unsaved changes to the current show will be lost.")
        }
    }
    
    // MARK: - OSC

    private func handleOSC(_ command: OSCCommand) {
        switch command {
        case .start:    engine.start()
        case .go:       engine.go()
        case .stop:     engine.stop()
        case .reset:    engine.reset()
        case .save:     engine.save()
        case .showstop: engine.showStop()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading — new show + open
        ToolbarItemGroup(placement: .navigation) {
            Button {
                showingNewShow = true
            } label: {
                Image(systemName: "plus.square")
            }
            .help("New Show")

            Button {
                confirmOpenShow = true
            } label: {
                Image(systemName: "folder")
            }
            .help("Open Show")
            .disabled(engine.isRunning)
            
            Button {
                saveShow(show: engine.showRun.show)
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Save Show")
        }

        // Centre — show title
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(engine.showRun.show.title)
                    .font(.headline)
                Text(engine.showRun.show.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            .padding(.horizontal, 16)

        }

        // Trailing — OSC status, save, export, settings
        ToolbarItemGroup(placement: .primaryAction) {
            // OSC status dot
            HStack(spacing: 4) {
                Circle()
                    .fill(oscListener.isListening ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("OSC")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
            .help(oscListener.isListening
                  ? "OSC listening on port \(String(oscListener.port))"
                  : "OSC not listening")

            Button {
                showingLog = true
            } label: {
                Image(systemName: "table")
            }
            .help("Log Table")
            .disabled(engine.showRun.entries.count == 0)
            
            Button {
                showingExport = true
            } label: {
                Image(systemName: "doc")
            }
            .help("Export Report")
            .disabled(engine.showRun.entries.count == 0)
            
            Button {
                openWindow(id: "monitor")
            } label: {
                Image(systemName: "tv")
            }
            .help("Toggle Popout")

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
    }
}

struct ModalHeaderView: View {
    @ObservedObject var engine: TimerEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(engine.showRun.show.title)
                .font(.callout).fontWeight(.medium)
            Text("\(engine.showRun.entries.count) logged events · \(engine.showRun.totalDuration.stopwatchFormatted) total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ExportSheetView
/// Sheet for choosing export format and triggering export.
struct ExportSheetView: View {
    @ObservedObject var engine: TimerEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Export Show Report")
                .font(.title2).bold()

            if engine.showRun.entries.count > 0 {
                
                ModalHeaderView(engine: engine)

                VStack(spacing: 10) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            ExportManager.export(engine.showRun, format: format)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: formatIcon(format))
                                    .frame(width: 24)
                                Text(format.label)
                                Spacer()
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No show run data available to export.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func formatIcon(_ format: ExportFormat) -> String {
        switch format {
        case .txt:  return "doc.text"
        case .json: return "curlybraces"
        case .pdf:  return "doc.richtext"
        }
    }
}

// MARK: - LogSheetView
struct LogSheetView: View {
    @ObservedObject var engine: TimerEngine
    @Environment(\.dismiss) var dismiss

    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Event Log")
                .font(.title2).bold()
            
            if engine.showRun.entries.count > 0 {
                
                ModalHeaderView(engine: engine)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(engine.showRun.entries) { entry in
                        Text("[\(entry.wallClockTime.formatted(date: .omitted, time: .standard))] +\(entry.showElapsed.stopwatchFormatted) \(entry.actName) > \(entry.sectionName) - \(entry.event.rawValue)")
                            .foregroundStyle(colourByEvent(event: entry.event))
                    }
                }
                
            } else {
                Text("No show run data available.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
    
    private func colourByEvent(event: TimestampEvent) -> Color {
        return switch event {
        case .started, .resumedFromPause, .showResumed: Color.green
        case .stopped, .paused:                         Color.orange
        case .showStopped, .showCancelled:              Color.red
        case .timestamp:                                Color.blue
        case .showCompleted:                            Color.green
        case .reset, .completed:                        Color.secondary
        }
    }
    
}
