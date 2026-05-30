import AppKit

final class CanvasController: NSViewController, CanvasMouseHandler {

    let state = CanvasState()
    let canvasView: CanvasView
    var colorState: ColorState?
    var toolController: ToolController?

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

    // MARK: - Helpers
    private func fgColor() -> (UInt8, UInt8, UInt8) {
        if let cs = colorState {
            return cs.fgColor
        }
        return (0, 0, 0)
    }

    private func bgColor() -> (UInt8, UInt8, UInt8) {
        if let cs = colorState {
            return cs.bgColor
        }
        return (255, 255, 255)
    }

    private func colorFromButton(_ button: String) -> (UInt8, UInt8, UInt8) {
        switch button {
        case "left":  return fgColor()
        case "right": return bgColor()
        default:      return fgColor()
        }
    }

    // Bresenham interpolation: draws all pixels between two points
    private func interpolatePoints(_ p0: NSPoint, _ p1: NSPoint) -> [NSPoint] {
        var points: [NSPoint] = []
        let x0 = Int(p0.x.rounded())
        let y0 = Int(p0.y.rounded())
        let x1 = Int(p1.x.rounded())
        let y1 = Int(p1.y.rounded())
        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        var cx = x0
        var cy = y0
        while true {
            points.append(NSPoint(x: CGFloat(cx), y: CGFloat(cy)))
            if cx == x1 && cy == y1 { break }
            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                cx += sx
            }
            if e2 < dx {
                err += dx
                cy += sy
            }
        }
        return points
    }

    // MARK: - CanvasMouseHandler
    func handleMouseEvent(kind: CanvasMouseEventKind, point: (Int, Int)) {
        guard let tc = toolController else { return }
        let nsPoint = NSPoint(x: CGFloat(point.0), y: CGFloat(point.1))

        tc.options.currentZoom = state.zoom
        var ctx = ToolContext(
            bitmap: state.bitmap,
            fgColor: fgColor(),
            bgColor: bgColor(),
            options: tc.options
        )

        switch kind {
        case .down:
            tc.activeTool.pointerDown(&ctx, nsPoint)
        case .dragged:
            tc.activeTool.pointerDragged(&ctx, nsPoint)
        case .up:
            tc.activeTool.pointerUp(&ctx, nsPoint)
            if case .pickColor(let fg, let r, let g, let b) = ctx.result {
                let hex = String(format: "#%02X%02X%02X", r, g, b)
                if fg {
                    self.colorState?.setForeground(hex)
                } else {
                    self.colorState?.setBackground(hex)
                }
                self.state.dirty = false
            } else if case .zoom(let percent) = ctx.result {
                self.state.zoom = percent
                self.toolController?.options.magnifierZoom = percent
                self.state.dirty = false
            } else {
                state.pushUndo()
                state.dirty = true
            }
        }

        state.bitmap = ctx.bitmap
        canvasView.bitmap = state.bitmap
        canvasView.needsDisplay = true
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
                if let tc = self.toolController {
                    var opts = ToolOptions()
                    opts.currentZoom = 100
                    tc.options = opts
                }
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
            guard let tc = self.toolController else { return .internalServerError("no tool controller") }
            struct Body: Decodable { let x: Int; let y: Int; let button: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"x\":int,\"y\":int,\"button\":\"left|right\"}")
            }
            let nsPoint = NSPoint(x: CGFloat(b.x), y: CGFloat(b.y))

            // Determine effective fg color based on button (primary=fg, secondary=bg)
            let effectiveFg = b.button == "right" ? self.bgColor() : self.fgColor()
            let toolButton: ToolButton = b.button == "right" ? .secondary : .primary

            DispatchQueue.main.sync {
                tc.options.currentZoom = self.state.zoom
                var ctx = ToolContext(
                    bitmap: self.state.bitmap,
                    fgColor: effectiveFg,
                    bgColor: self.bgColor(),
                    options: tc.options,
                    button: toolButton
                )
                tc.activeTool.pointerDown(&ctx, nsPoint)
                tc.activeTool.pointerUp(&ctx, nsPoint)
                self.state.bitmap = ctx.bitmap

                // Handle zoom result
                if case .zoom(let percent) = ctx.result {
                    self.state.zoom = percent
                    tc.options.currentZoom = percent
                    self.state.dirty = false
                // Handle pick-color result
                } else if case .pickColor(let fg, let r, let g, let b) = ctx.result {
                    let hex = String(format: "#%02X%02X%02X", r, g, b)
                    if fg {
                        self.colorState?.setForeground(hex)
                    } else {
                        self.colorState?.setBackground(hex)
                    }
                    self.state.dirty = false
                } else {
                    self.state.pushUndo()
                    self.state.dirty = true
                }

                self.canvasView.bitmap = self.state.bitmap
                self.canvasView.needsDisplay = true
            }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }

        // POST /canvas/stroke {"points":[[x,y],...],"button":"left"}
        router.post(prefix: Self.routePrefix, path: "/stroke") { [weak self] req in
            guard let self else { return .notFound(req) }
            guard let tc = self.toolController else { return .internalServerError("no tool controller") }
            struct Body: Decodable { let points: [[Int]]; let button: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"points\":[[x,y],...],\"button\":\"left|right\"}")
            }
            guard b.points.allSatisfy({ $0.count == 2 }) else {
                return .badRequest("each point must be [x,y]")
            }
            guard !b.points.isEmpty else {
                let json = try? JSONEncoder().encode(["ok": true])
                return .ok(json: json ?? Data())
            }

            let pts = b.points.map { NSPoint(x: CGFloat($0[0]), y: CGFloat($0[1])) }

            let effectiveFg = b.button == "right" ? self.bgColor() : self.fgColor()
            let toolButton: ToolButton = b.button == "right" ? .secondary : .primary

            DispatchQueue.main.sync {
                var ctx = ToolContext(
                    bitmap: self.state.bitmap,
                    fgColor: effectiveFg,
                    bgColor: self.bgColor(),
                    options: tc.options,
                    button: toolButton
                )

                // pointerDown on first point
                tc.activeTool.pointerDown(&ctx, pts[0])

                // Interpolate between consecutive points for gap-free stroking
                if pts.count > 1 {
                    for i in 0..<(pts.count - 1) {
                        let interpolated = self.interpolatePoints(pts[i], pts[i + 1])
                        // Skip first point of each segment since it was already drawn by previous segment's last point
                        for j in 1..<interpolated.count {
                            tc.activeTool.pointerDragged(&ctx, interpolated[j])
                        }
                    }
                }

                // pointerUp on last point
                tc.activeTool.pointerUp(&ctx, pts.last!)

                self.state.bitmap = ctx.bitmap
                if case .zoom(let percent) = ctx.result {
                    self.state.zoom = percent
                    self.toolController?.options.currentZoom = percent
                    self.state.dirty = false
                } else {
                    self.state.pushUndo()
                    self.state.dirty = true
                }
                self.canvasView.bitmap = self.state.bitmap
                self.canvasView.zoom = self.state.zoom
                self.canvasView.needsDisplay = true
            }

            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }
    }
}
