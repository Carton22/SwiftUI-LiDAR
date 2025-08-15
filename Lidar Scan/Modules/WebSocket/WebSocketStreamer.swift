import SwiftUI

struct MeshPayload: Codable {
    let id: String
    let vertices: [Float]
    let faces: [[UInt32]]
    let transform: [Float]
    let timestamp: Double
}
struct MeshEnvelope: Codable {
    let type: String
    let data: MeshPayload
}

final class WebSocketStreamer: ObservableObject {
    @Published var isConnected = false

    private let session = URLSession(configuration: .default)
    private var websocketTask: URLSessionWebSocketTask?
    private let sendQueue = DispatchQueue(label: "ws.send.queue")
    private var pingTimer: Timer?
    private var lastURL: URL?
    private var reconnectAttempts = 0

    // MARK: - Connect / Disconnect
    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else { print("Bad URL"); return }
        lastURL = url
        let task = session.webSocketTask(with: url)
        websocketTask = task
        task.resume()
        isConnected = true
        reconnectAttempts = 0
        print("WebSocket connected to: \(urlString)")

        receiveLoop()
        startPing()

        // Optional greeting
        sendString("Hello from iOS iPad testing now")
    }

    func disconnect() {
        stopPing()
        reconnectAttempts = 0
        websocketTask?.cancel(with: .goingAway, reason: nil)
        websocketTask = nil
        isConnected = false
    }

    // MARK: - Receive
    private func receiveLoop() {
        websocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("Receive error: \(error)")
                self.handleDisconnect()
            case .success(let message):
                switch message {
                case .string(let s): print("RX:", s.prefix(200))
                case .data(let d):   print("RX data (\(d.count) bytes)")
                @unknown default:    break
                }
                // keep draining
                self.receiveLoop()
            }
        }
    }

    // MARK: - Ping
    private func startPing() {
        stopPing()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let task = self?.websocketTask else { return }
            task.sendPing { err in
                if let err = err { print("Ping failed:", err) }
                else { /* print("Ping OK") */ }
            }
        }
    }
    private func stopPing() { pingTimer?.invalidate(); pingTimer = nil }

    // MARK: - Reconnect
    private func handleDisconnect() {
        guard isConnected else { return }
        isConnected = false
        stopPing()
        websocketTask?.cancel()
        websocketTask = nil

        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // 1,2,4,8,…,30s
        reconnectAttempts += 1
        print("Scheduling reconnect in \(delay)s (attempt \(reconnectAttempts))")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let url = self.lastURL else { return }
            self.connect(to: url.absoluteString)
        }
    }

    // MARK: - Send (centralized)
    private func send(_ message: URLSessionWebSocketTask.Message, label: String) {
        guard isConnected, let task = websocketTask else {
            print("WebSocket not connected (during \(label))")
            return
        }
        sendQueue.async {
            task.send(message) { error in
                if let error = error {
                    print("Send error (\(label)): \(error)")
                } else {
                    print("Sent OK (\(label))")
                }
            }
        }
    }

    func sendString(_ text: String) {
        send(.string(text), label: "string")
    }

    // MARK: - Mesh Create / Update
    func sendMeshCreate(_ mesh: MeshData) {
        guard isConnected else { print("WebSocket not connected"); return }
        do {
            let json = try makeJSON(envelopeType: "mesh_create", mesh: mesh)
            print("Encoding OK (mesh_create)")
            sendString(json)
        } catch {
            print("JSON encode failed (mesh_create): \(error)")
        }
    }

    func sendMeshUpdate(_ mesh: MeshData) {
        guard isConnected else { print("WebSocket not connected"); return }
        do {
            let json = try makeJSON(envelopeType: "mesh_update", mesh: mesh)
            sendString(json)
        } catch {
            print("JSON encode failed (mesh_update): \(error)")
        }
    }

    // MARK: - JSON helpers
    private func makeJSON(envelopeType: String, mesh: MeshData) throws -> String {
        let payload = MeshPayload(
            id: mesh.id,
            vertices: sanitize(mesh.vertices),
            faces: mesh.faces,
            transform: sanitize(mesh.transform),
            timestamp: mesh.timestamp
        )
        let envelope = MeshEnvelope(type: envelopeType, data: payload)
        let encoder = JSONEncoder()

        // If your server can accept stringified NaN/Inf, use:
        // encoder.nonConformingFloatEncodingStrategy = .convertToString(
        //     positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN"
        // )

        let data = try encoder.encode(envelope)
        guard let s = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "UTF8", code: -1, userInfo: [NSLocalizedDescriptionKey: "UTF8 encode failed"])
        }
        return s
    }

    // Replace non-finite values if your server expects numbers only.
    private func sanitize(_ values: [Float]) -> [Float] {
        values.map { $0.isFinite ? $0 : 0 }
    }
}
