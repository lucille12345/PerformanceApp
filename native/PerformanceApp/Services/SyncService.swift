import Foundation
import Network
import Observation

/// Syncs the whole data set with the app on your other devices over the local Wi-Fi network.
/// Each device advertises itself with Bonjour; when two find each other they exchange their data,
/// merge it, and from then on push every change to each other within half a second.
@MainActor @Observable
final class SyncService {
    static let serviceType = "_perfsync._tcp"

    @ObservationIgnored var snapshot: (() -> AppData)?
    @ObservationIgnored var onReceive: ((AppData) -> Void)?

    /// Names of the devices currently connected ("iPhone", "Mac").
    private(set) var peerNames: [String] = []

    private struct Message: Codable {
        var from: String
        var device: String
        var data: AppData
    }

    private final class Peer {
        let connection: NWConnection
        var buffer = Data()
        var id: String?
        var device: String?
        var ready = false
        init(_ c: NWConnection) { connection = c }
    }

    @ObservationIgnored private let instanceID: String = {
        if let id = UserDefaults.standard.string(forKey: "syncInstanceID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "syncInstanceID")
        return id
    }()

    static var deviceName: String {
        #if os(iOS)
        "iPhone"
        #else
        "Mac"
        #endif
    }

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var peers: [Peer] = []

    private var serviceName: String { "\(Self.deviceName)~\(instanceID)" }

    private static var parameters: NWParameters {
        let p = NWParameters.tcp
        p.includePeerToPeer = true
        return p
    }

    func start() {
        guard listener == nil else { return }
        if let l = try? NWListener(using: Self.parameters) {
            l.service = NWListener.Service(name: serviceName, type: Self.serviceType)
            l.newConnectionHandler = { [weak self] c in
                Task { @MainActor in self?.adopt(c) }
            }
            l.stateUpdateHandler = { [weak self] state in
                if case .failed = state { Task { @MainActor in self?.restartLater() } }
            }
            l.start(queue: .main)
            listener = l
        }

        let b = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: Self.parameters)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.found(results) }
        }
        b.stateUpdateHandler = { [weak self] state in
            if case .failed = state { Task { @MainActor in self?.restartLater() } }
        }
        b.start(queue: .main)
        browser = b
    }

    func stop() {
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
        peers.forEach { $0.connection.cancel() }
        peers = []
        updateNames()
    }

    /// Called when the app comes back to the foreground: iOS drops connections in the background.
    func restart() {
        stop()
        start()
    }

    private func restartLater() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            restart()
        }
    }

    func broadcast(_ data: AppData) {
        guard let frame = Self.frame(Message(from: instanceID, device: Self.deviceName, data: data)) else { return }
        for p in peers where p.ready { p.connection.send(content: frame, completion: .contentProcessed { _ in }) }
    }

    // MARK: Connections

    private func found(_ results: Set<NWBrowser.Result>) {
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            let otherID = String(name.split(separator: "~").last ?? "")
            // Only one side dials, so each pair of devices has a single connection.
            guard otherID != instanceID, instanceID < otherID, !peers.contains(where: { $0.id == otherID }) else { continue }
            let c = NWConnection(to: result.endpoint, using: Self.parameters)
            let peer = adopt(c)
            peer.id = otherID
        }
    }

    @discardableResult
    private func adopt(_ connection: NWConnection) -> Peer {
        let peer = Peer(connection)
        peers.append(peer)
        connection.stateUpdateHandler = { [weak self, weak peer] state in
            Task { @MainActor in
                guard let self, let peer else { return }
                switch state {
                case .ready:
                    peer.ready = true
                    if let data = self.snapshot?(),
                       let frame = Self.frame(Message(from: self.instanceID, device: Self.deviceName, data: data)) {
                        peer.connection.send(content: frame, completion: .contentProcessed { _ in })
                    }
                    self.receive(peer)
                case .failed, .cancelled:
                    self.drop(peer)
                default: break
                }
            }
        }
        connection.start(queue: .main)
        return peer
    }

    private func receive(_ peer: Peer) {
        peer.connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self, weak peer] content, _, isComplete, error in
            Task { @MainActor in
                guard let self, let peer else { return }
                if let content { peer.buffer.append(content); self.drain(peer) }
                if isComplete || error != nil { peer.connection.cancel(); return }
                self.receive(peer)
            }
        }
    }

    /// Messages are a 4-byte big-endian length followed by JSON.
    private func drain(_ peer: Peer) {
        while peer.buffer.count >= 4 {
            let len = peer.buffer.prefix(4).reduce(0) { $0 << 8 | Int($1) }
            guard peer.buffer.count >= 4 + len else { return }
            let body = peer.buffer.subdata(in: peer.buffer.startIndex + 4 ..< peer.buffer.startIndex + 4 + len)
            peer.buffer = Data(peer.buffer.dropFirst(4 + len))
            guard let msg = try? JSONDecoder().decode(Message.self, from: body), msg.from != instanceID else { continue }
            if peer.id != nil, peer.id != msg.from { continue }
            peer.id = msg.from
            if peer.device == nil { peer.device = msg.device; updateNames() }
            onReceive?(msg.data)
        }
    }

    private func drop(_ peer: Peer) {
        guard peers.contains(where: { $0 === peer }) else { return }
        peers.removeAll { $0 === peer }
        updateNames()
        // Redial devices that are still advertised.
        Task {
            try? await Task.sleep(for: .seconds(3))
            if let b = browser { found(b.browseResults) }
        }
    }

    private func updateNames() {
        peerNames = Array(Set(peers.compactMap(\.device))).sorted()
    }

    private static func frame(_ message: Message) -> Data? {
        guard let body = try? JSONEncoder().encode(message) else { return nil }
        let n = UInt32(body.count)
        var out = Data([UInt8(n >> 24 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)])
        out.append(body)
        return out
    }
}
