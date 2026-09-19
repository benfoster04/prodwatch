
import SwiftUI

@main
struct prodwatchApp: App {
    
    @Environment(\.openURL) var openURL
    @Environment(\.openWindow) private var openWindow
    private var oscListener: OSCListener = OSCListener()
    private var engine: TimerEngine = TimerEngine()
    
    var body: some Scene {
        let contentView: ContentView = ContentView(
            engine: engine,
            oscListener: oscListener
        )
        WindowGroup { contentView }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(before: .windowArrangement) {
                Button("Toggle Popout", systemImage: "tv") {
                    openWindow(id: "monitor")
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Show", systemImage: "plus.square") {
                    NewShowView() { newShow in
                        engine.loadShow(newShow)
                    }
                }
                .keyboardShortcut("N")
                .disabled(engine.isRunning || engine.isPaused)
                
                Button("Open Show", systemImage: "folder") {
                    if let newshow = openShow(engine: engine) {
                        engine.loadShow(newshow)
                    }
                }
                .keyboardShortcut("O")
                .disabled(engine.isRunning || engine.isPaused)
                
                Button("Save Show", systemImage: "square.and.arrow.down") {
                    saveShow(show: engine.showRun.show)
                }
                .keyboardShortcut("S")
                .disabled(engine.isRunning || engine.isPaused)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit", systemImage: "multiply.circle") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("Q")
                .disabled(engine.isRunning || engine.isPaused)
                
                Button("Close", systemImage: "multiply.circle") {
                    NSApplication.shared.keyWindow?.performClose(nil)
                }
                .keyboardShortcut("W")
                .disabled(engine.isRunning || engine.isPaused)
            }
            CommandGroup(replacing: .help) {
                Button("Help", systemImage: "book") {
                    if let url = URL(string: "https://github.com/benfoster04/prodwatch/wiki") { openURL(url) }
                }
            }
        }
        
        WindowGroup("Monitor", id: "monitor") {
            PopoutView(engine: engine)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 300, height: 300)
        .commandsRemoved()
        

        Settings {
            SettingsView(oscListener: oscListener)
        }
    }
    
}
// MARK: - Monitor Menu Button
/// Separate view so it can access @Environment(\.openWindow)
private struct OpenWindowAction_MonitorButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Monitor Window") {
            openWindow(id: "monitor")
        }
//        .keyboardShortcut("m", modifiers: [.command, .shift])
    }
}
