import AppKit

final class CanvasController: NSViewController, CanvasMouseHandler, TestAPIControllerRoutes {

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

    func performUndo() {
        if Thread.isMainThread {
            if state.undo() {
                canvasView.bitmap = state.bitmap
                canvasView.needsDisplay = true
            }
        } else {
            DispatchQueue.main.sync {
                if state.undo() {
                    canvasView.bitmap = state.bitmap
                    canvasView.needsDisplay = true
                }
            }
        }
    }

    func performRedo() {
        if Thread.isMainThread {
            if state.redo() {
                canvasView.bitmap = state.bitmap
                canvasView.needsDisplay = true
            }
        } else {
            DispatchQueue.main.sync {
                if state.redo() {
                    canvasView.bitmap = state.bitmap
                    canvasView.needsDisplay = true
                }
            }
        }
    }

    // MARK: - Helpers
    fileprivate func fgColor() -> (UInt8, UInt8, UInt8) {
        if let cs = colorState { return cs.fgColor }
        return (0, 0, 0)
    }

    fileprivate func bgColor() -> (UInt8, UInt8, UInt8) {
        if let cs = colorState { return cs.bgColor }
        return (255, 255, 255)
    }

    fileprivate func colorFromButton(_ button: String) -> (UInt8, UInt8, UInt8) {
        switch button {
        case "left":  return fgColor()
        case "right": return bgColor()
        default:      return fgColor()
        }
    }

    // Bresenham interpolation: draws all pixels between two points
    fileprivate func interpolatePoints(_ p0: NSPoint, _ p1: NSPoint) -> [NSPoint] {
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

    // MARK: - TestAPIControllerRoutes
    static var routePrefix: String { "canvas" }

    func registerRoutes(on router: TestAPIRouter) {
        // GET /canvas/state
        router.get(prefix: Self.routePrefix, path: "/state") { req in
            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                guard let canvas = Self.findCanvas(windowId: req.query["windowId"]) else {
                    result = .notFound(req)
                    return
                }
                var dict: [String: Any] = [:]
                dict["canvas"] = ["w": canvas.state.bitmap.width, "h": canvas.state.bitmap.height]
                dict["zoom"] = canvas.state.zoom
                dict["dirty"] = canvas.state.dirty
                dict["filePath"] = canvas.state.filePath ?? NSNull()
                dict["drawOpaque"] = canvas.state.drawOpaque
                dict["selection"] = canvas.state.selection ?? NSNull()
                guard let body = try? JSONSerialization.data(withJSONObject: dict) else {
                    result = .internalServerError("JSON encode failed")
                    return
                }
                result = .ok(json: body)
            }
            return result ?? .internalServerError("no response")
        }

        // POST /canvas/new
        router.post(prefix: Self.routePrefix, path: "/new") { req in
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

            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                guard let canvas = Self.findCanvas(windowId: req.query["windowId"]) else {
                    result = .internalServerError("no canvas available")
                    return
                }
                canvas.state.bitmap = Bitmap(width: w, height: h)
                canvas.state.zoom = 100
                canvas.state.dirty = false
                canvas.state.filePath = nil
                canvas.state.selection = nil
                canvas.state.clearUndo()
                canvas.canvasView.bitmap = canvas.state.bitmap
                canvas.canvasView.needsDisplay = true
                if let tc = canvas.toolController {
                    var opts = ToolOptions()
                    opts.currentZoom = 100
                    tc.options = opts
                }
                if let body = try? JSONEncoder().encode(["ok": true]) {
                    result = .ok(json: body)
                } else {
                    result = .internalServerError("JSON encode failed")
                }
            }
            return result ?? .internalServerError("no response")
        }

        // GET /canvas/pixel?x=&y=
        router.get(prefix: Self.routePrefix, path: "/pixel") { req in
            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                guard let canvas = Self.findCanvas(windowId: req.query["windowId"]) else {
                    result = .notFound(req)
                    return
                }
                guard let xStr = req.query["x"], let yStr = req.query["y"],
                      let x = Int(xStr), let y = Int(yStr) else {
                    result = .badRequest("query params x and y required")
                    return
                }
                var dict: [String: Any] = [:]
                dict["x"] = x
                dict["y"] = y
                if let (r, g, b) = canvas.state.bitmap.pixelAt(x: x, y: y) {
                    dict["color"] = String(format: "#%02X%02X%02X", r, g, b)
                } else {
                    dict["color"] = "#000000"
                }
                guard let json = try? JSONSerialization.data(withJSONObject: dict) else {
                    result = .internalServerError("JSON encode failed")
                    return
                }
                result = .ok(json: json)
            }
            return result ?? .internalServerError("no response")
        }

        // POST /canvas/pixel?x=&y=  (test harness uses POST for pixel readback)
        router.post(prefix: Self.routePrefix, path: "/pixel") { req in
            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                guard let canvas = Self.findCanvas(windowId: req.query["windowId"]) else {
                    result = .notFound(req)
                    return
                }
                guard let xStr = req.query["x"], let yStr = req.query["y"],
                      let x = Int(xStr), let y = Int(yStr) else {
                    result = .badRequest("query params x and y required")
                    return
                }
                var dict: [String: Any] = [:]
                dict["x"] = x
                dict["y"] = y
                if let (r, g, b) = canvas.state.bitmap.pixelAt(x: x, y: y) {
                    dict["color"] = String(format: "#%02X%02X%02X", r, g, b)
                } else {
                    dict["color"] = "#000000"
                }
                guard let json = try? JSONSerialization.data(withJSONObject: dict) else {
                    result = .internalServerError("JSON encode failed")
                    return
                }
                result = .ok(json: json)
            }
            return result ?? .internalServerError("no response")
        }

        // POST /canvas/click {"x":10,"y":10,"button":"left"}
        router.post(prefix: Self.routePrefix, path: "/click") { req in
            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                guard let canvas = Self.findCanvas(windowId: req.query["windowId"]) else {
                    result = .notFound(req)
                    return
                }
                guard let tc = canvas.toolController else {
                    result = .internalServerError("no tool controller")
                    return
                }
                struct Body: Decodable { let x: Int; let y: Int; let button: String }
                guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                    result = .badRequest("body must be {\"x\":int,\"y\":int,\"button\":\"left|right\"}")
                    return
                }
                let nsPoint = NSPoint(x: CGFloat(b.x), y: CGFloat(b.y))

                let effectiveFg = b.button == "right" ? canvas.bgColor() : canvas.fgColor()
                let toolButton: ToolButton = b.button == "right" ? .secondary : .primary

                tc.options.currentZoom = canvas.state.zoom
                var ctx = ToolContext(
                    bitmap: canvas.state.bitmap,
                    fgColor: effectiveFg,
                    bgColor: canvas.bgColor(),
                    options: tc.options,
                    button: toolButton
                )
                tc.activeTool.pointerDown(&ctx, nsPoint)
                tc.activeTool.pointerUp(&ctx, nsPoint)
                canvas.state.bitmap = ctx.bitmap

                if case .zoom(let percent) = ctx.result {
                    canvas.state.zoom = percent
                    tc.options.currentZoom = percent
                    canvas.state.dirty = false
                } else if case .pickColor(let fg, let r, let g, let pb) = ctx.result {
                    let hex = String(format: "#%02X%02X%02X", r, g, pb)
                    if fg {
                        canvas.colorState?.setForeground(hex)
                    } else {
                        canvas.colorState?.setBackground(hex)
                    }
                    canvas.state.dirty = false
                } else {
                    canvas.state.pushUndo()
                    canvas.state.dirty = true
                }

                canvas.canvasView.bitmap = canvas.state.bitmap
                canvas.canvasView.needsDisplay = true

                if let body = try? JSONEncoder().encode(["ok": true]) {
                    result = .ok(json: body)
                } else {
                    result = .internalServerError("JSON encode failed")
                }
            }
            return result ?? .internalServerError("no response")
        }

        // POST /canvas/stroke {"points":[[x,y],...],"button":"left"}
        router.post(prefix: Self.routePrefix, path: "/stroke") { req in
            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                guard let canvas = Self.findCanvas(windowId: req.query["windowId"]) else {
                    result = .notFound(req)
                    return
                }
                guard let tc = canvas.toolController else {
                    result = .internalServerError("no tool controller")
                    return
                }
                struct Body: Decodable { let points: [[Int]]; let button: String }
                guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                    result = .badRequest("body must be {\"points\":[[x,y],...],\"button\":\"left|right\"}")
                    return
                }
                guard b.points.allSatisfy({ $0.count == 2 }) else {
                    result = .badRequest("each point must be [x,y]")
                    return
                }
                guard !b.points.isEmpty else {
                    if let body = try? JSONEncoder().encode(["ok": true]) {
                        result = .ok(json: body)
                    } else {
                        result = .internalServerError("JSON encode failed")
                    }
                    return
                }

                let pts = b.points.map { NSPoint(x: CGFloat($0[0]), y: CGFloat($0[1])) }

                let effectiveFg = b.button == "right" ? canvas.bgColor() : canvas.fgColor()
                let toolButton: ToolButton = b.button == "right" ? .secondary : .primary

                var ctx = ToolContext(
                    bitmap: canvas.state.bitmap,
                    fgColor: effectiveFg,
                    bgColor: canvas.bgColor(),
                    options: tc.options,
                    button: toolButton
                )

                tc.activeTool.pointerDown(&ctx, pts[0])

                if pts.count > 1 {
                    for i in 0..<(pts.count - 1) {
                        let interpolated = canvas.interpolatePoints(pts[i], pts[i + 1])
                        for j in 1..<interpolated.count {
                            tc.activeTool.pointerDragged(&ctx, interpolated[j])
                        }
                    }
                }

                tc.activeTool.pointerUp(&ctx, pts.last!)

                canvas.state.bitmap = ctx.bitmap
                if case .zoom(let percent) = ctx.result {
                    canvas.state.zoom = percent
                    canvas.toolController?.options.currentZoom = percent
                    canvas.state.dirty = false
                } else {
                    canvas.state.pushUndo()
                    canvas.state.dirty = true
                }
                canvas.canvasView.bitmap = canvas.state.bitmap
                canvas.canvasView.zoom = canvas.state.zoom
                canvas.canvasView.needsDisplay = true

                if let body = try? JSONEncoder().encode(["ok": true]) {
                    result = .ok(json: body)
                } else {
                    result = .internalServerError("JSON encode failed")
                }
            }
            return result ?? .internalServerError("no response")
        }
    }

    // MARK: - Static helpers for multi-window canvas lookup (call only on main thread)

    static func findCanvas(windowId: String?) -> CanvasController? {
        if let wid = windowId, !wid.isEmpty {
            if let win = TestAPIWindowStore.shared.window(id: wid) as? PigmentWindow {
                return win.canvasController
            }
            return nil
        }
        // No windowId: prefer the most recently opened document window
        if let lastDoc = DocumentController.latestDocWindow() {
            return lastDoc
        }
        // Fall back to TestAPIWindowStore (handles early startup and explicit registrations)
        if let win = TestAPIWindowStore.shared.window(id: nil) as? PigmentWindow {
            return win.canvasController
        }
        // Last resort: iterate windows
        for win in NSApp.windows {
            if let pw = win as? PigmentWindow {
                return pw.canvasController
            }
        }
        return nil
    }
}
