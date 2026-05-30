import AppKit

final class ZoomController: NSViewController {

    var zoomLevels: [Int] = [100, 200, 400, 600, 800]
    private var currentZoom: Int = 100
    private var showGrid: Bool = false

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }

    func magnifierCycle(currentPercent: Int) -> Int {
        guard let idx = zoomLevels.firstIndex(of: currentPercent) else { return 100 }
        return zoomLevels[(idx + 1) % zoomLevels.count]
    }

    func setZoom(_ percent: Int, windowId: String?) -> Bool {
        guard zoomLevels.contains(percent) else { return false }
        currentZoom = percent
        showGrid = (percent >= 400)
        return true
    }

    var effectiveZoom: Int { currentZoom }
    var effectiveShowGrid: Bool { showGrid }
}

// MARK: - Routes
extension ZoomController: TestAPIControllerRoutes {

    static var routePrefix: String { "zoom" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/set") { [weak self] req in
            guard let self else { return .notFound(req) }
            struct Body: Decodable { let percent: Int; let windowId: String? }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"percent\":400,\"windowId\"?:\"w1\"}")
            }
            guard self.zoomLevels.contains(b.percent) else {
                return .badRequest("invalid zoom: \(b.percent)")
            }
            var ok = false
            DispatchQueue.main.sync {
                if let wid = b.windowId,
                   let win = TestAPIWindowStore.shared.window(id: wid),
                   let pw = win as? PigmentWindow {
                    pw.canvasController.state.zoom = b.percent
                    pw.canvasController.canvasView.zoom = b.percent
                    ok = true
                } else if let win = TestAPIWindowStore.shared.window(id: nil),
                          let pw = win as? PigmentWindow {
                    pw.canvasController.state.zoom = b.percent
                    pw.canvasController.canvasView.zoom = b.percent
                    ok = true
                }
                self.currentZoom = b.percent
                self.showGrid = (b.percent >= 400)
            }
            guard ok else { return .badRequest("window not found") }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/grid") { [weak self] req in
            guard let self else { return .notFound(req) }
            struct Body: Decodable { let on: Bool; let windowId: String? }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"on\":true,\"windowId\"?:\"w1\"}")
            }
            DispatchQueue.main.sync {
                self.showGrid = b.on
            }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }
    }
}
