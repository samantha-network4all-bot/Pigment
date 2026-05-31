import AppKit

final class AppController: NSObject {

    func startTestAPIIfNeeded() {
        guard ProcessInfo.processInfo.environment["PIGMENT_TEST_API"] == "1" else { return }
        TestAPIRouter.shared.register(controller: self)
        TestAPIServer.shared.start()
    }
}

// MARK: - Top-level orchestrator routes
extension AppController: TestAPIControllerRoutes {

    static var routePrefix: String { "" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(path: "/healthz") { _ in
            let body = try! JSONEncoder().encode(["ok": true] as [String: Bool])
            return .ok(json: body)
        }

        router.get(path: "/screenshot") { req in
            let windowId = req.query["windowId"]
            let region = req.query["region"] ?? "window"

            if region == "canvas" {
                return .notFound(req)
            }

            var response: TestAPIResponse?
            DispatchQueue.main.sync {
                guard let win = TestAPIWindowStore.shared.window(id: windowId) else {
                    response = .notFound(req)
                    return
                }

                win.displayIfNeeded()

                guard let view = win.contentView else {
                    response = .internalServerError("no contentView")
                    return
                }

                let captureRect = view.bounds

                guard let rep = view.bitmapImageRepForCachingDisplay(in: captureRect) else {
                    response = .internalServerError("bitmapImageRep failed")
                    return
                }
                view.cacheDisplay(in: captureRect, to: rep)
                guard let png = rep.representation(using: .png, properties: [:]) else {
                    response = .internalServerError("png encoding failed")
                    return
                }

                response = .ok(data: png, contentType: "image/png")
            }
            return response ?? .internalServerError("no response")
        }

        router.post(path: "/shutdown") { _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            let body = try! JSONEncoder().encode(["ok": true] as [String: Bool])
            return .ok(json: body)
        }
    }
}

// Simple window store so handlers can look up windows by id
final class TestAPIWindowStore {
    static let shared = TestAPIWindowStore()
    private var windows: [String: NSWindow] = [:]

    func register(id: String, window: NSWindow) {
        windows[id] = window
    }

    func window(id: String?) -> NSWindow? {
        if let id = id {
            return windows[id]
        }
        if let key = NSApp.keyWindow { return key }
        if let first = NSApp.windows.first { return first }
        // Fallback: return the first registered window (useful during early startup)
        return windows.values.first
    }
}
