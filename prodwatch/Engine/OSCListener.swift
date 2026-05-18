import Foundation
import SwiftUI
import Network
import Combine

// MARK: - OSCListener
/// Listens on a UDP port for OSC messages
@MainActor
final class OSCListener: ObservableObject {
    
    @AppStorage("autoStartOSC") private var autoStartOSC: Bool?

    // MARK: Published State
    @Published var isListening: Bool = false
    @Published var lastMessage: String = ""
    @Published var port: UInt16 = 53000

    // MARK: Private
    private var listener: NWListener?
    private var onCommand: ((OSCCommand) -> Void)?

    // MARK: - Start / Stop

    func start(port: UInt16, onCommand: @escaping (OSCCommand) -> Void) {
        self.port = port
        self.onCommand = onCommand
        startListener()
        autoStartOSC = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
        autoStartOSC = false
    }

    func restart(port: UInt16, onCommand: @escaping (OSCCommand) -> Void) {
        stop()
        start(port: port, onCommand: onCommand)
    }

    // MARK: - Private

    private func startListener() {
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[OSC] Failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { connection in
            connection.start(queue: .global(qos: .userInteractive))
            Task { @MainActor [weak self] in
                self?.receive(on: connection)
            }
        }

        listener?.stateUpdateHandler = { state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.isListening = true
                    print("[OSC] Listening on port \(String(self?.port ?? 0))")
                case .failed(let error):
                    self?.isListening = false
                    print("[OSC] Listener failed: \(error)")
                case .cancelled:
                    self?.isListening = false
                default:
                    break
                }
            }
        }

        listener?.start(queue: .global(qos: .userInteractive))
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { data, _, isComplete, error in
            // Parse off the main actor — no self capture needed here
            let command: OSCCommand? = data.flatMap { OSCParser.parse($0) }

            Task { @MainActor [weak self] in
                if let command {
                    self?.lastMessage = command.rawValue
                    self?.onCommand?(command)
                }
                if isComplete == false, error == nil {
                    self?.receive(on: connection)
                }
            }
        }
    }
}

// MARK: - OSC Commands
enum OSCCommand: String {
    case start      = "/stopwatch/start"
    case go         = "/stopwatch/go"
    case stop       = "/stopwatch/stop"
    case reset      = "/stopwatch/reset"
    case save       = "/stopwatch/save"
    case showstop   = "/stopwatch/showstop"
}

// MARK: - OSC Parser
enum OSCParser {

    static func parse(_ data: Data) -> OSCCommand? {
        guard let address = extractAddress(from: data) else { return nil }
        return OSCCommand(rawValue: address)
    }

    // MARK: Private

    /// OSC address string starts at byte 0 and is null-terminated, padded to 4-byte boundary
    private static func extractAddress(from data: Data) -> String? {
        guard data.first == UInt8(ascii: "/") else { return nil }

        // Find null terminator
        guard let nullIndex = data.firstIndex(of: 0) else { return nil }
        guard nullIndex > 0 else { return nil }

        return String(bytes: data[0..<nullIndex], encoding: .utf8)
    }
}
