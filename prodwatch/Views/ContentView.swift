import SwiftUI

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
    @AppStorage("autoStartOSC")     private var autoStartOSC: Bool = false

    @State private var colorSchemeID: UUID = UUID()
    @State private var showingExport    = false
    @State private var showingLog       = false
    @State private var showingNewShow   = false
    @State private var confirmNewShow   = false
    @State private var confirmOpenShow  = false
    
    // Used by FileManager
    @State var showError = false

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
        .alert(
            Text(engine.error?.errorDescription ?? "Error"),
            isPresented: Binding(
                get: { engine.error != nil },
                set: { if !$0 { engine.error != nil } }
            ),
            presenting: engine.error
        ) { _ in
            Button("Dismiss", role: .cancel) {}
        } message: { error in
            Text(error.recoverySuggestion ?? "Unknown")
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
                if let newshow = openShow(engine: engine) {
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
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
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
