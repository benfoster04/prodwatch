import SwiftUI

// MARK: - TimerDisplayView
/// Main clock face — shows section timer, show timer, pause/stop counters,
/// target delta, and primary transport controls.
struct TimerDisplayView: View {
    @ObservedObject var engine: TimerEngine
    @Binding var show: Show
    @State private var showingShowStop = false

    var body: some View {
        VStack(spacing: 0) {
            // Section + Act name
            

            // Main clock area
            VStack(spacing: 24) {
                
                Spacer()
                
                sectionHeader
                
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
                Spacer()

                // Transport controls
                transportControls

                // Show stop button
                showStopButton
            }
            .padding(32)
        }
        .sheet(isPresented: $showingShowStop) {
            ShowStopView(engine: engine, show: show)
        }
    }
    
    // MARK: - Section Header
    private var sectionHeader: some View {
        HStack(spacing: 24) {
            Button {
                engine.previousSection()
            } label: {
                Image(systemName: "chevron.left.circle")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(engine.isShowStopped || engine.isShowCancelled)
            
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
            
            Button {
                engine.nextSection()
            } label: {
                Image(systemName: "chevron.right.circle")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(engine.isShowStopped || engine.isShowCancelled)

        }
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

    // MARK: - Transport Controls
    private var transportControls: some View {
        HStack(spacing: 20) {
            // Reset
            Button {
                engine.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(engine.isShowStopped || engine.isShowCancelled)

            // Play / Pause
            Button {
                if engine.isRunning {
                    engine.stop()
                } else {
                    engine.start()
                }
            } label: {
                Image(systemName: playPauseIcon)
                    .font(.system(size: 28))
                    .frame(width: 72, height: 72)
                    .background(playPauseColor)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .shadow(color: playPauseColor.opacity(0.4), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(engine.isShowStopped || engine.isShowCancelled || engine.currentSection == nil)

            // Go — advances sequentially, spacebar shortcut
            Button {
                engine.go()
            } label: {
                Text("GO")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(engine.isShowStopped || engine.isShowCancelled || !engine.isRunning)
        }
    }

    // MARK: - Show Stop Button
    private var showStopButton: some View {
        Button {
            if engine.isShowStopped {
                showingShowStop = true
            } else {
                engine.showStop()
                showingShowStop = true
            }
        } label: {
            Label(
                engine.isShowStopped ? "Resolve Show Stop" : "Show Stop",
                systemImage: engine.isShowStopped ? "exclamationmark.triangle.fill" : "stop.circle"
            )
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(engine.isShowStopped ? .white : .red)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(engine.isShowStopped ? Color.red : Color.red.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(engine.isShowCancelled) // TODO: !engine.isRunning doesn't work here is the engine stops during a show stop, so prevents resuming from show stop if popup is dismissed.
        .padding(.top, 8)
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

    private var playPauseIcon: String {
        if engine.isShowStopped  { return "stop.fill" }
        if engine.isRunning      { return "pause.fill" }
        return "play.fill"
    }

    private var playPauseColor: Color {
        if engine.isShowStopped { return .red }
        if engine.isRunning     { return .orange }
        return .accentColor
    }
}
