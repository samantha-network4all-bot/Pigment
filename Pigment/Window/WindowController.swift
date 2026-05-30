import AppKit

final class WindowController: NSWindowController {

    private static var windowCount = 0
    let windowId: String
    private let zoomController: ZoomController

    init() {
        let window = PigmentWindow()
        WindowController.windowCount += 1
        self.windowId = "w\(WindowController.windowCount)"
        self.zoomController = ZoomController()
        super.init(window: window)

        // Ensure ZoomController's viewDidLoad fires so routes register
        _ = zoomController.view

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
                guard let win = TestAPIWindowStore.shared.window(id: nil),
                      let wc = win.windowController as? WindowController else {
                    response = .internalServerError("no window")
                    return
                }
                let obj: [String: Any] = [
                    "id": wc.windowId,
                    "title": win.title,
                    "isKey": true
                ]
                if let body = try? JSONSerialization.data(withJSONObject: obj) {
                    response = .ok(json: body)
                } else {
                    response = .internalServerError("JSON encode failed")
                }
            }
            return response ?? .internalServerError("no response")
        }
    }
}
