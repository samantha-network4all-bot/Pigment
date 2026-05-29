import Foundation
import Network

final class TestAPIServer {
    static let shared = TestAPIServer()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.bimboware.pigment.testapi")

    private init() {}

    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            listener = try NWListener(using: parameters, on: .any)
        } catch {
            print("TestAPIServer: failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                guard let port = self?.listener?.port else { return }
                self?.writePortFile(Int(port.rawValue))
            case .failed(let error):
                print("TestAPIServer: listener failed: \(error)")
            default:
                break
            }
        }
    }

    private func writePortFile(_ port: Int) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Pigment/test-api.port")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("\(port)\n".utf8)
        try? data.write(to: url)
        print("TestAPI: port \(port)")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHTTP(connection: connection)
    }

    private func receiveHTTP(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                connection.cancel()
                return
            }

            guard let data = data, !data.isEmpty else {
                if isComplete {
                    connection.cancel()
                    return
                }
                self?.receiveHTTP(connection: connection)
                return
            }

            let selfCopy = self
            selfCopy?.handleRequest(data: data, connection: connection)

            if !isComplete {
                self?.receiveHTTP(connection: connection)
            }
        }
    }

    private func handleRequest(data: Data, connection: NWConnection) {
        guard let raw = String(data: data, encoding: .utf8) else {
            sendResponse(TestAPIResponse.badRequest("invalid encoding"), on: connection)
            return
        }

        let lines = raw.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            sendResponse(TestAPIResponse.badRequest("empty request"), on: connection)
            return
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else {
            sendResponse(TestAPIResponse.badRequest("malformed request line"), on: connection)
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        var bodyStartIndex = 0
        for (i, line) in lines.enumerated() {
            if i == 0 { continue }
            if line.isEmpty {
                bodyStartIndex = i + 1
                break
            }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                headers[String(headerParts[0]).trimmingCharacters(in: .whitespaces)] = String(headerParts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        let bodyData: Data
        if bodyStartIndex > 0 && bodyStartIndex < lines.count {
            let bodyLines = lines[bodyStartIndex...]
            let bodyString = bodyLines.joined(separator: "\r\n")
            bodyData = Data(bodyString.utf8)
        } else {
            bodyData = Data()
        }

        let request = TestAPIRequest(method: method, path: path, headers: headers, body: bodyData)
        let response = TestAPIRouter.shared.dispatch(request)
        sendResponse(response, on: connection)
    }

    private func sendResponse(_ response: TestAPIResponse, on connection: NWConnection) {
        var headerLines: [String] = []
        headerLines.append("HTTP/1.1 \(response.status) \(response.statusText)")
        headerLines.append("Content-Type: \(response.contentType)")
        headerLines.append("Content-Length: \(response.data.count)")
        headerLines.append("Connection: close")
        headerLines.append("")
        headerLines.append("")

        var responseData = Data(headerLines.joined(separator: "\r\n").utf8)
        responseData.append(response.data)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
