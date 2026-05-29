import AppKit

final class CanvasController: NSViewController, CanvasMouseHandler {

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
        canvasView.mouseHandler = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }

    // MARK: - CanvasMouseHandler
    func handleMouseEvent(kind: CanvasMouseEventKind, point: (Int, Int)) {
        // Stub: tools will be wired here in a later slice
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

        // GET /canvas/pixel?x=&y=
        router.get(prefix: Self.routePrefix, path: "/pixel") { [weak self] req in
            guard let self else { return .notFound(req) }
            guard let xStr = req.query["x"], let yStr = req.query["y"],
                  let x = Int(xStr), let y = Int(yStr) else {
                return .badRequest("query params x and y required")
            }
            var result: [String: Any] = [:]
            DispatchQueue.main.sync {
                result["x"] = x
                result["y"] = y
                if let (r, g, b) = self.state.bitmap.pixelAt(x: x, y: y) {
                    result["color"] = String(format: "#%02X%02X%02X", r, g, b)
                } else {
                    result["color"] = "#000000"
                }
            }
            guard let json = try? JSONSerialization.data(withJSONObject: result) else {
                return .internalServerError("JSON encode failed")
            }
            return .ok(json: json)
        }

        // POST /canvas/click {"x":10,"y":10,"button":"left"}
        router.post(prefix: Self.routePrefix, path: "/click") { [weak self] req in
            guard let self else { return .notFound(req) }
            struct Body: Decodable { let x: Int; let y: Int; let button: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"x\":int,\"y\":int,\"button\":\"left|right\"}")
            }
            let color = self.colorFromButton(b.button)
            DispatchQueue.main.sync {
                self.state.pushUndo()
                self.state.bitmap.setPixel(x: b.x, y: b.y, color: color)
                self.state.dirty = true
                self.canvasView.needsDisplay = true
            }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }

        // POST /canvas/stroke {"points":[[x,y],...],"button":"left"}
        router.post(prefix: Self.routePrefix, path: "/stroke") { [weak self] req in
            guard let self else { return .notFound(req) }
            struct Body: Decodable { let points: [[Int]]; let button: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"points\":[[x,y],...],\"button\":\"left|right\"}")
            }
            guard b.points.allSatisfy({ $0.count == 2 }) else {
                return .badRequest("each point must be [x,y]")
            }
            let color = self.colorFromButton(b.button)
            let pts = b.points.map { ($0[0], $0[1]) }
            DispatchQueue.main.sync {
                self.state.pushUndo()
                self.state.bitmap.drawDottedLine(points: pts, color: color)
                self.state.dirty = true
                self.canvasView.needsDisplay = true
            }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }
    }

    private func colorFromButton(_ button: String) -> (UInt8, UInt8, UInt8) {
        switch button {
        case "left":  return (0, 0, 0)       // foreground: black
        case "right": return (255, 255, 255)   // background: white
        default:      return (0, 0, 0)
        }
    }
}
