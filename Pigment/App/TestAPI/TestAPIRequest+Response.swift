import Foundation

struct TestAPIRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    init(method: String, path: String, headers: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.body = body
        self.headers = headers

        let parts = path.split(separator: "?", maxSplits: 1)
        self.path = String(parts[0])
        if parts.count > 1 {
            self.query = String(parts[1])
                .split(separator: "&")
                .reduce(into: [String: String]()) { dict, pair in
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    if kv.count == 2 {
                        dict[String(kv[0])] = String(kv[1])
                    }
                }
        } else {
            self.query = [:]
        }
    }
}

enum TestAPIResponse {
    case jsonOk(Data)
    case rawOk(Data, contentType: String)
    case badRequest(String)
    case notFound(TestAPIRequest)
    case conflict(String)
    case internalServerError(String)

    static func ok(json: Data) -> Self { .jsonOk(json) }
    static func ok(data: Data, contentType: String) -> Self { .rawOk(data, contentType: contentType) }

    var status: Int {
        switch self {
        case .jsonOk, .rawOk: return 200
        case .badRequest: return 400
        case .notFound: return 404
        case .conflict: return 409
        case .internalServerError: return 500
        }
    }

    var statusText: String {
        switch self {
        case .jsonOk, .rawOk: return "OK"
        case .badRequest: return "Bad Request"
        case .notFound: return "Not Found"
        case .conflict: return "Conflict"
        case .internalServerError: return "Internal Server Error"
        }
    }

    var data: Data {
        switch self {
        case .jsonOk(let json):
            return json
        case .rawOk(let data, _):
            return data
        case .badRequest(let msg),
             .conflict(let msg):
            return Data("{\"error\":\"\(msg)\"}".utf8)
        case .notFound:
            return Data("{\"error\":\"not found\"}".utf8)
        case .internalServerError(let msg):
            return Data("{\"error\":\"\(msg)\"}".utf8)
        }
    }

    var contentType: String {
        switch self {
        case .jsonOk:
            return "application/json"
        case .rawOk(_, let contentType):
            return contentType
        case .badRequest, .notFound, .conflict, .internalServerError:
            return "application/json"
        }
    }
}
