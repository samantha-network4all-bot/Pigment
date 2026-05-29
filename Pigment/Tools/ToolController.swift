import AppKit

final class ToolController: NSViewController {

    var options = ToolOptions()

    private(set) var activeToolId: String = "pencil"

    private var allTools: [String: Tool] = [:]
    private var _activeTool: Tool

    var activeTool: Tool { _activeTool }

    init() {
        // Create all 16 tools
        var tools: [String: Tool] = [:]
        tools["pencil"] = PencilTool()
        tools["line"] = LineTool()
        tools["eraser"] = EraserTool()
        let stubIds = [
            "freeform-select", "select",
            "magnifier",
            "text", "curve",
            "polygon", "ellipse", "rounded-rectangle"
        ]
        for sid in stubIds {
            tools[sid] = StubTool(toolId: sid)
        }
        tools["rectangle"] = RectangleTool()
        tools["brush"] = BrushTool()
        tools["airbrush"] = AirbrushTool()
        tools["fill"] = FillTool()
        tools["pick-color"] = PickColorTool()
        self.allTools = tools
        self._activeTool = tools["pencil"]!

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }

    func selectTool(id: String) -> Bool {
        guard let tool = allTools[id] else { return false }
        _activeTool = tool
        activeToolId = id
        return true
    }

    func colorFromButton(_ button: String, fg: (UInt8, UInt8, UInt8), bg: (UInt8, UInt8, UInt8)) -> (UInt8, UInt8, UInt8) {
        switch button {
        case "left":  return fg
        case "right": return bg
        default:      return fg
        }
    }
}

// MARK: - Routes
extension ToolController: TestAPIControllerRoutes {

    static var routePrefix: String { "tool" }

    func registerRoutes(on router: TestAPIRouter) {
        // POST /tool/select {"tool":"pencil"}
        router.post(prefix: Self.routePrefix, path: "/select") { [weak self] req in
            guard let self else { return .notFound(req) }
            struct Body: Decodable { let tool: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"tool\":\"pencil\"}")
            }
            var ok = false
            DispatchQueue.main.sync {
                ok = self.selectTool(id: b.tool)
            }
            guard ok else { return .badRequest("unknown tool: \(b.tool)") }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }

        // POST /tool/options {...}
        router.post(prefix: Self.routePrefix, path: "/options") { [weak self] req in
            guard let self else { return .notFound(req) }
            struct Body: Decodable {
                let lineWidth: Int?
                let brushSize: Int?
                let eraserSize: Int?
                let airbrushSize: Int?
                let fillMode: String?
                let transparentSelection: Bool?
                let textStyle: String?
            }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("invalid body")
            }
            DispatchQueue.main.sync {
                if let v = b.lineWidth { self.options.lineWidth = v }
                if let v = b.brushSize { self.options.brushSize = v }
                if let v = b.eraserSize { self.options.eraserSize = v }
                if let v = b.airbrushSize { self.options.airbrushSize = v }
                if let v = b.fillMode { self.options.fillMode = v }
                if let v = b.transparentSelection { self.options.transparentSelection = v }
                if let v = b.textStyle { self.options.textStyle = v }
            }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }

        // GET /tool/state
        router.get(prefix: Self.routePrefix, path: "/state") { [weak self] req in
            guard let self else { return .notFound(req) }
            var result: [String: Any] = [:]
            var opts: [String: Any] = [:]
            DispatchQueue.main.sync {
                result["tool"] = self.activeToolId
                opts["lineWidth"] = self.options.lineWidth
                opts["brushSize"] = self.options.brushSize
                opts["eraserSize"] = self.options.eraserSize
                opts["airbrushSize"] = self.options.airbrushSize
                opts["fillMode"] = self.options.fillMode
                opts["transparentSelection"] = self.options.transparentSelection
                opts["textStyle"] = self.options.textStyle
            }
            result["options"] = opts
            guard let json = try? JSONSerialization.data(withJSONObject: result) else {
                return .internalServerError("JSON encode failed")
            }
            return .ok(json: json)
        }
    }
}
