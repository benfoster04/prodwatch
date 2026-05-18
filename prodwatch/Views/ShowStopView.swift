import SwiftUI

// MARK: - ShowStopView
/// Modal sheet presented during a show stop.
/// Allows the SM to resolve the stop by resuming from current,
/// jumping to a specific section, or cancelling the show entirely.
struct ShowStopView: View {
    @ObservedObject var engine: TimerEngine
    let show: Show
    @Environment(\.dismiss) var dismiss

    @State private var selectedActIndex: Int = 0
    @State private var selectedSectionIndex: Int = 0
    @State private var showCancelConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Show stop duration
                    stopDurationBanner

                    // Option 1 — Resume from current
                    resumeFromCurrentOption

                    Divider()

                    // Option 2 — Resume from chosen section
                    resumeFromSectionOption

                    Divider()

                    // Option 3 — Cancel show
                    cancelShowOption
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 560)
        .confirmationDialog(
            "Cancel Show",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel Show", role: .destructive) {
                engine.resolveShowStop(.cancelShow)
                dismiss()
            }
            Button("Keep Show Stopped", role: .cancel) {}
        } message: {
            Text("This will mark the run as cancelled. All logged timestamps will still be available for export.")
        }
        .onAppear {
            selectedActIndex = engine.currentActIndex
            selectedSectionIndex = engine.currentSectionIndex
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Show Stopped")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose how to proceed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Stop Duration Banner

    private var stopDurationBanner: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STOPPED FOR")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .tracking(2)
                Text(engine.showStopElapsed.adaptiveFormatted)
                    .font(.system(size: 36, weight: .thin, design: .monospaced))
                    .foregroundStyle(.red)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.01), value: engine.showStopElapsed)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SHOW ELAPSED")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .tracking(2)
                Text(engine.showElapsed.adaptiveFormatted)
                    .font(.system(size: 22, weight: .light, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Resume from Current

    private var resumeFromCurrentOption: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Resume from Current Section", systemImage: "play.circle.fill")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.green)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.currentSection?.name ?? "—")
                        .font(.callout)
                    Text(engine.currentAct?.name ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Resume Here") {
                    engine.resolveShowStop(.resumeFromCurrent)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(12)
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Resume from Section

    private var resumeFromSectionOption: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Resume from a Different Section", systemImage: "forward.circle.fill")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)

            // Act picker
            VStack(alignment: .leading, spacing: 8) {
                Picker("Act", selection: $selectedActIndex) {
                    ForEach(show.acts.indices, id: \.self) { i in
                        Text(show.acts[i].name).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedActIndex) {
                    selectedSectionIndex = 0
                }

                // Section picker for chosen act
                if selectedActIndex < show.acts.count {
                    let sections = show.acts[selectedActIndex].sections
                    if sections.isEmpty {
                        Text("No sections in this act")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Section", selection: $selectedSectionIndex) {
                            ForEach(sections.indices, id: \.self) { i in
                                HStack {
                                    Text(sections[i].name)
                                    Text(sections[i].sectionType.rawValue)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Resume from Selected") {
                    engine.resolveShowStop(.resumeFromSection(
                        actIndex: selectedActIndex,
                        sectionIndex: selectedSectionIndex
                    ))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedActIndex >= show.acts.count ||
                          selectedSectionIndex >= (show.acts[safe: selectedActIndex]?.sections.count ?? 0))
            }
        }
    }

    // MARK: - Cancel Show

    private var cancelShowOption: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cancel Show", systemImage: "xmark.circle.fill")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.red)

            Text("Marks this run as cancelled. The show cannot be resumed after this. All timestamps logged so far will remain available for export.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel Show") {
                    showCancelConfirm = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
}

// MARK: - Safe Array Subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
