import SwiftUI

// MARK: - SettingsView
/// App settings — OSC configuration, appearance, and export preferences.
struct SettingsView: View {
    @ObservedObject var oscListener: OSCListener
    @AppStorage("oscPort")          private var oscPort: Int = 53000
    @AppStorage("showCentiseconds") private var showCentiseconds: Bool = false
    @AppStorage("colorScheme")      private var colorSchemePreference: ColorSchemePreference = .system
    @AppStorage("defaultVenue")     private var defaultVenue: String = ""
    @AppStorage("defaultSavePath")  private var defaultSavePath: URL = URL(string: "~/Documents")!
    @AppStorage("defaultSaveType")  private var defaultSaveType: ExportFormat = .pdf
    @AppStorage("autoCreateTimer")  private var autoCreateTimer: Bool = true

    @State private var portInput: String = ""
    @State private var portError: String? = nil

    var body: some View {
        TabView {
            oscTab
                .tabItem { Label("OSC", systemImage: "network") }

            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            exportTab
                .tabItem { Label("Export", systemImage: "doc") }
        }
        .frame(width: 460, height: 320)
        .onAppear {
            portInput = String(oscPort)
        }
    }

    // MARK: - OSC Tab

    private var oscTab: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    // Status indicator
                    Circle()
                        .fill(oscListener.isListening ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(oscListener.isListening
                         ? "Listening on port \(String(oscListener.port))"
                         : "Not listening")
                        .font(.callout)
                    Spacer()
                    Button(oscListener.isListening ? "Stop" : "Start") {
                        oscListener.isListening ? oscListener.stop() : applyPort()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } header: {
                Text("Status")
            }

            Section {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Port", text: $portInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .onChange(of: portInput) { validatePort() }

                    Button("Apply") {
                        applyPort()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(portError != nil)

                    if let err = portError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Text("Default: 53000. Valid range: 1024–65535.\nMatch this port in your QLab Network cue destination.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("UDP Port")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Supported OSC addresses:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    oscAddressRow("/stopwatch/start")
                    oscAddressRow("/stopwatch/go")
                    oscAddressRow("/stopwatch/stop")
                    oscAddressRow("/stopwatch/reset")
                    oscAddressRow("/stopwatch/save")
                    oscAddressRow("/stopwatch/showstop")
                }

                if !oscListener.lastMessage.isEmpty {
                    HStack {
                        Text("Last received:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(oscListener.lastMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            } header: {
                Text("QLab Reference")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section {
                Picker("Colour Scheme", selection: $colorSchemePreference) {
                    ForEach(ColorSchemePreference.allCases) { pref in
                        Text(pref.label).tag(pref)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Theme")
            }

            Section {
                Toggle("Show centiseconds on section timer", isOn: $showCentiseconds)
                    .disabled(true)
                Text("[Deprecated] Disabling this reduces visual noise and visual impact.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Timer Display")
            }
            
            Section {
                Toggle("Auto create Primary timer", isOn: $autoCreateTimer)
                Text("When enabled, this auto-creates a Primary timer when creating a section with the same name as the section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Behaviour")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    // MARK: - Export Tab

    private var exportTab: some View {
        Form {
            Section {
                TextField("Default venue name", text: $defaultVenue)
                    .textFieldStyle(.roundedBorder)
                Text("Pre-fills the venue field when creating a new show.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Save path", value:$defaultSavePath, format: URL.FormatStyle(), prompt: Text("~/Documents"))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button("Open Folder") {
                        openFolder()
                    }
                }
                
                Picker("Save file type", selection: $defaultSaveType) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                Text("Both used when the save file OSC command is sent. Does not affect the staandard save file function")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Defaults")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    exportFormatRow(
                        icon: "doc.text",
                        format: "TXT",
                        description: "Plain text timestamp log — good for archiving or pasting into reports"
                    )
                    Divider()
                    exportFormatRow(
                        icon: "curlybraces",
                        format: "JSON",
                        description: "Full structured data export — useful for integration with other tools"
                    )
                    Divider()
                    exportFormatRow(
                        icon: "doc.richtext",
                        format: "PDF",
                        description: "Formatted show report with colour-coded event log — good for sharing"
                    )
                }
            } header: {
                Text("Export Formats")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }
    
    // MARK: - Open Folder
    private func openFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        defaultSavePath = url
    }

    // MARK: - Helpers

    private func oscAddressRow(_ address: String) -> some View {
        Text(address)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Color.accentColor)
            .padding(.leading, 8)
    }

    private func exportFormatRow(icon: String, format: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(format)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func validatePort() {
        guard let p = Int(portInput) else {
            portError = "Must be a number"
            return
        }
        portError = (1024...65535).contains(p) ? nil : "Must be 1024–65535"
    }

    private func applyPort() {
        guard let p = Int(portInput), portError == nil else { return }
        oscPort = p
        // Notify OSCListener
        NotificationCenter.default.post(
            name: .oscPortDidChange,
            object: nil,
            userInfo: ["port": p]
        )
    }
}

// MARK: - Colour Scheme Preference
enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let oscPortDidChange = Notification.Name("oscPortDidChange")
}
