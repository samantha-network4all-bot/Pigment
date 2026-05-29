import AppKit

final class CanvasController: NSViewController {

    let state = CanvasState()
    let canvasView: CanvasView

    init() {
        self.canvasView = CanvasView(frame: NSRect(origin: .zero, size: Metrics.defaultCanvas))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Metrics.defaultCanvas))
        canvasView.frame = container.bounds
        canvasView.autoresizingMask = [.width, .height]
        container.addSubview(canvasView)
        self.view = container

        canvasView.bitmap = state.bitmap
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }
}

// MARK: - Routes
extension CanvasController: TestAPIControllerRoutes {

    static var routePrefix: String { "canvas" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/state") { [weak self] req in
            guard let self else { return .notFound(req) }

            var result: [String: Any] = [:]
            result["canvas"] = ["w": self.state.bitmap.width, "h": self.state.bitmap.height]
            result["zoom"] = self.state.zoom
            result["dirty"] = self.state.dirty
            result["filePath"] = self.state.filePath ?? NSNull()
            result["drawOpaque"] = self.state.drawOpaque
            result["selection"] = self.state.selection ?? NSNull()

            guard let body = try? JSONSerialization.data(withJSONObject: result) else {
                return .internalServerError("JSON encode failed")
            }
            return .ok(json: body)
        }

        router.post(prefix: Self.routePrefix, path: "/new") { [weak self] req in
            guard let self else { return .notFound(req) }

            struct Body: Decodable {
                let w: Int?
                let h: Int?
            }

            let w: Int
            let h: Int
            if let b = try? JSONDecoder().decode(Body.self, from: req.body) {
                w = b.w ?? 800
                h = b.h ?? 600
            } else {
                w = 800
                h = 600
            }

            DispatchQueue.main.sync {
                self.state.bitmap = Bitmap(width: w, height: h)
                self.state.zoom = 100
                self.state.dirty = false
                self.state.filePath = nil
                self.state.selection = nil
                self.state.clearRedo()
                self.canvasView.bitmap = self.state.bitmap
                self.canvasView.needsDisplay = true
            }

            let body = try? JSONEncoder().encode(["ok": true])
            return .ok(json: body ?? Data())
        }
    }
}
