import SwiftUI
import AppKit

// MARK: - PopoutView
/// Floating monitor window. Design this however you like —
/// all TimerEngine state is available via `engine`.
struct PopoutView: View {
    @ObservedObject var engine: TimerEngine
    @State private var staysOnTop: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        
        VStack(alignment: .center, spacing: 16) {
            
            VStack(alignment: .center, spacing: 2) {
                
                Text(engine.currentSection?.name ?? "—")
                    .font(.system(size: 40, weight: .semibold, design: .default))
                    .lineLimit(1)
                    .frame(minWidth: 150, idealWidth: 300)
                
                Text(engine.currentAct?.name ?? "—")
                    .font(.system(size: 32, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 150, idealWidth: 300)
                    
            }
            
            Spacer()

            // Primary section timer
            sectionTimer

            // Target delta indicator
            if let delta = engine.targetDelta {
                targetDeltaView(delta)
            }

            // Secondary timers row
            secondaryTimers
            
            Spacer()
        }
        .padding(32)
        .toolbar {
            ToolbarItem(id: "staysOnTop", placement: .status) {
                Button {
                    staysOnTop.toggle()
                } label: {
                    Image(systemName: staysOnTop ? "pin.fill" : "pin")
                        .frame(width: 24, height: 24)
                        .background(staysOnTop ? Color.secondary : Color.secondary.opacity(0.15))
                        .foregroundStyle(Color.secondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(staysOnTop ? "Disable Stay on Top" : "Enable Stay on Top")
            }
        }
        .background(WindowLevelSetter(staysOnTop: staysOnTop))
        
    }

    // MARK: - Section Timer
    private var sectionTimer: some View {
        VStack(spacing: 6) {
            Text(engine.sectionElapsed.adaptiveFormatted)
                .font(.system(size: 72, weight: .thin, design: .monospaced))
                .foregroundStyle(sectionTimerColor)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.01), value: engine.sectionElapsed)

            Text("SECTION")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .tracking(2)
        }
    }

    // MARK: - Target Delta
    private func targetDeltaView(_ delta: TimeInterval) -> some View {
        HStack(spacing: 6) {
            Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                .font(.caption)
            Text(abs(delta).shortFormatted)
                .font(.system(.callout, design: .monospaced))
            Text(delta >= 0 ? "over target" : "under target")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(deltaColor(delta))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(deltaColor(delta).opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Secondary Timers
    private var secondaryTimers: some View {
        HStack(spacing: 32) {
            // Global show timer
            secondaryTimer(
                value: engine.showElapsed.adaptiveFormatted,
                label: "SHOW",
                color: .primary
            )

            // Pause counter — only visible when paused
            if engine.isPaused {
                secondaryTimer(
                    value: engine.pauseElapsed.shortFormatted,
                    label: "PAUSED",
                    color: .orange
                )
            }

            // Show stop counter — only visible during show stop
            if engine.isShowStopped {
                secondaryTimer(
                    value: engine.showStopElapsed.shortFormatted,
                    label: "SHOW STOP",
                    color: .red
                )
            }
        }
    }

    private func secondaryTimer(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .light, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.01), value: value)
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .tracking(2)
        }
    }
    
    // MARK: - Colour Logic
    private var sectionTimerColor: Color {
        if engine.isShowCancelled { return .secondary }
        if engine.isShowStopped   { return .red }
        if engine.isPaused        { return .orange }
        if let delta = engine.targetDelta {
            return deltaColor(delta)
        }
        return .primary
    }

    private func deltaColor(_ delta: TimeInterval) -> Color {
        if delta < 0                        { return .green }
        if delta < 30                       { return .primary }
        if delta < 60                       { return .orange }
        return .red
    }
}

// MARK: - WindowLevelSetter
/// Zero-size AppKit bridge that finds the host NSWindow and sets its level.
private struct WindowLevelSetter: NSViewRepresentable {
    let staysOnTop: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.level = staysOnTop ? .floating : .normal
                window.hidesOnDeactivate = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
        }
    }
}
