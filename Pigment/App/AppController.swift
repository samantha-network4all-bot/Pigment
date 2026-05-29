import AppKit

final class AppController: NSObject {

    func startTestAPIIfNeeded() {
        guard ProcessInfo.processInfo.environment["PIGMENT_TEST_API"] == "1" else { return }
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

            guard let win = TestAPIWindowStore.shared.window(id: windowId) else {
                return .notFound(req)
            }

            DispatchQueue.main.sync {
                win.displayIfNeeded()
            }

            guard let view = win.contentView else {
                return .internalServerError("no contentView")
            }

            var captureRect = view.bounds
            if let frameStr = req.query["frame"] {
                let parts = frameStr.split(separator: ",").compactMap { Int($0) }
                if parts.count == 4 {
                    captureRect = NSRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                }
            }

            guard let rep = view.bitmapImageRepForCachingDisplay(in: captureRect) else {
                return .internalServerError("bitmapImageRep failed")
            }
            view.cacheDisplay(in: captureRect, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else {
                return .internalServerError("png encoding failed")
            }

            return .ok(data: png, contentType: "image/png")
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
        return NSApp.keyWindow ?? NSApp.windows.first
    }
}
