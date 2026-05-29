import AppKit

final class WindowController: NSWindowController {

    private static var windowCount = 0
    let windowId: String

    init() {
        let window = PigmentWindow()
        WindowController.windowCount += 1
        self.windowId = "w\(WindowController.windowCount)"
        super.init(window: window)

        _ = window.contentRect(forFrameRect: window.frame)

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
        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] _ in
            guard let self else { return .notFound(.init(method: "GET", path: "")) }

            guard let win = NSApp.windows.first(where: { ($0.windowController as? WindowController) != nil }),
                  let wc = win.windowController as? WindowController else {
                return .notFound(.init(method: "GET", path: ""))
            }

            let dict: [String: Any] = [
                "id": wc.windowId,
                "title": win.title,
                "isKey": win.isKeyWindow
            ]
            guard let body = try? JSONSerialization.data(withJSONObject: dict) else {
                return .internalServerError("JSON encode failed")
            }
            return .ok(json: body)
        }
    }
}
