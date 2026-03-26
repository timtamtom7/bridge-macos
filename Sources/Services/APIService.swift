import Foundation
import Network

// MARK: - Bridge R14: REST API (port 8776) & Webhooks

final class BridgeAPIService: ObservableObject {
    static let shared = BridgeAPIService()

    private var listener: NWListener?
    private let port: UInt16 = 8776
    @Published var isRunning = false

    private init() {}

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async { self?.isRunning = state == .ready }
            }
            listener?.newConnectionHandler = { [weak self] conn in
                self?.handle(conn)
            }
            listener?.start(queue: .global())
        } catch { print("BridgeAPI error: \(error)") }
    }

    func stop() {
        listener?.cancel(); listener = nil
        DispatchQueue.main.async { self.isRunning = false }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global())
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let data = data, let req = String(data: data, encoding: .utf8) else { conn.cancel(); return }
            let resp = self?.route(req) ?? BridgeHTTPResp(code: 404, body: #"{"error":"Not found"}"#)
            let http = "HTTP/1.1 \(resp.code)\r\nContent-Type: application/json\r\nContent-Length: \(resp.body.count)\r\n\r\n\(resp.body)"
            conn.send(content: http.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    struct BridgeHTTPResp { let code: Int; let body: String }

    private func route(_ req: String) -> BridgeHTTPResp {
        let lines = req.split(separator: "\r\n")
        guard let rl = lines.first else { return BridgeHTTPResp(code: 404, body: #"{"error":"Not found"}"#) }
        let parts = String(rl).split(separator: " ")
        guard parts.count >= 2 else { return BridgeHTTPResp(code: 404, body: #"{"error":"Not found"}"#) }
        let path = String(parts[1])
        guard lines.contains(where: { $0.hasPrefix("X-API-Key:") }) else {
            return BridgeHTTPResp(code: 401, body: #"{"error":"Unauthorized"}"#)
        }
        switch path {
        case "/devices": return BridgeHTTPResp(code: 200, body: "[]")
        case "/workflows": return BridgeHTTPResp(code: 200, body: "[]")
        case "/scenes": return BridgeHTTPResp(code: 200, body: "[]")
        case "/usage": return BridgeHTTPResp(code: 200, body: #"{"totalDevices":0}"#)
        case "/openapi.json": return BridgeHTTPResp(code: 200, body: openAPISpec())
        default: return BridgeHTTPResp(code: 404, body: #"{"error":"Not found"}"#)
        }
    }

    private func openAPISpec() -> String {
        return #"{"openapi":"3.0.0","info":{"title":"Bridge API","version":"1.0"},"paths":{"/devices":{"get":{"summary":"List connected devices"}},"/workflows":{"get":{"summary":"List workflows"}},"/scenes":{"get":{"summary":"List scenes"}},"/usage":{"get":{"summary":"Usage analytics"}}}}"#
    }
}

// MARK: - Bridge R15: iOS Companion Stub

final class BridgeiOSService: ObservableObject {
    static let shared = BridgeiOSService()
    @Published var connectedDevices: [iOSDeviceRef] = []
    @Published var widgetData: [String: Any] = [:]

    struct iOSDeviceRef: Identifiable {
        let id = UUID(); let name: String; let type: String
    }

    private init() {}
}
