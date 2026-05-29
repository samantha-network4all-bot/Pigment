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
            DispatchQueue.main.sync {
                let windows = NSApp.windows.compactMap { win -> [String: Any]? in
                    guard let wc = win.windowController as? WindowController else { return nil }
                    return [
                        "id": wc.windowId,
                        "title": win.title,
                        "isKey": win.isKeyWindow
                    ]
                }
                guard let body = try? JSONSerialization.data(withJSONObject: windows) else {
                    return .internalServerError("JSON encode failed")
                }
                return .ok(json: body)
            }
        }
    }
}
