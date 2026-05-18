
import SwiftUI

@main
struct prodwatchApp: App {
    
    private var oscListener: OSCListener = OSCListener()
    private var timerEngine: TimerEngine = TimerEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                engine: timerEngine,
                oscListener: oscListener
            )
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(before: .windowArrangement) {
                Button("Toggle Popout", systemImage: "tv") {
                    
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Show", systemImage: "plus.square") {
                    
                }
                .keyboardShortcut("N")
                .disabled(true)
                
                Button("Open Show", systemImage: "folder") {
                    
                }
                .keyboardShortcut("O")
                .disabled(true)
                
                Button("Save Show", systemImage: "square.and.arrow.down") {
                    
                }
                .keyboardShortcut("S")
                .disabled(true)
            }
        }
        
        WindowGroup("Monitor", id: "monitor") {
            PopoutView(engine: timerEngine)
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
