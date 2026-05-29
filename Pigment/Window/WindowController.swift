import AppKit

final class WindowController: NSWindowController {

    private static var windowCount = 0
    let windowId: String

    init() {
        let window = PigmentWindow()
        WindowController.windowCount += 1
        self.windowId = "w\(WindowController.windowCount)"
        super.init(window: window)

        TestAPIWindowStore.shared.register(id: windowId, window: window)
        TestAPIRouter.shared.register(controller: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }
}

// MARK: - Routes
extension WindowController: TestAPIControllerRoutes {

    static var routePrefix: String { "window" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/list") { _ in
            var response: TestAPIResponse?
            DispatchQueue.main.sync {
                let allWindows = NSApp.windows
                let keyWin = allWindows.first(where: { $0.isKeyWindow })
                let windows = allWindows.compactMap { win -> [String: Any]? in
                    guard let wc = win.windowController as? WindowController else { return nil }
                    // Treat as key if it is the key window, or if no window is key
                    // and this is the first visible one (headless launch scenario)
                    let isKey: Bool
                    if let kw = keyWin {
                        isKey = (win === kw)
                    } else {
                        isKey = (win === (allWindows.first { $0.isVisible }))
                    }
                    return [
                        "id": wc.windowId,
                        "title": win.title,
                        "isKey": isKey
                    ]
                }
                if let body = try? JSONSerialization.data(withJSONObject: windows) {
                    response = .ok(json: body)
                } else {
                    response = .internalServerError("JSON encode failed")
                }
            }
            return response ?? .internalServerError("no response")
        }
    }
}
