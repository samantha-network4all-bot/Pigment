import Foundation

protocol TestAPIControllerRoutes: AnyObject {
    static var routePrefix: String { get }
    func registerRoutes(on router: TestAPIRouter)
}

final class TestAPIRouter {
    static let shared = TestAPIRouter()
    private var handlers: [String: (TestAPIRequest) -> TestAPIResponse] = [:]

    private init() {}

    func get(prefix: String = "", path: String, _ handler: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let key = prefix.isEmpty
            ? "GET \(path)"
            : "GET /\(prefix)\(path)"
        handlers[key] = handler
    }

    func post(prefix: String = "", path: String, _ handler: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let key = prefix.isEmpty
            ? "POST \(path)"
            : "POST /\(prefix)\(path)"
        handlers[key] = handler
    }

    func register<C: TestAPIControllerRoutes>(controller: C) {
        controller.registerRoutes(on: self)
    }

    func dispatch(_ request: TestAPIRequest) -> TestAPIResponse {
        let key = "\(request.method) \(request.path)"
        if let handler = handlers[key] {
            return handler(request)
        }
        // Try matching with trailing-slash variants or prefix patterns
        for (pattern, handler) in handlers {
            if matches(pattern: pattern, request: key) {
                return handler(request)
            }
        }
        return .notFound(request)
    }

    private func matches(pattern: String, request: String) -> Bool {
        return pattern == request
    }
}
