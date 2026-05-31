import AppKit

final class DocumentController: NSViewController {

    weak var toolController: ToolController?
    weak var colorState: ColorState?

    // Retained references to document windows so test API can find them
    private static var nextDocWindowId = 2
    // Map windowId -> (window, canvasController)
    private static var docWindows: [String: (PigmentWindow, CanvasController)] = [:]
    private static var docWindowOrder: [String] = []

    override func loadView() {
        self.view = NSView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }

    private func keyCanvasController() -> CanvasController? {
        if let pw = (NSApp.keyWindow ?? NSApp.windows.first) as? PigmentWindow {
            return pw.canvasController
        }
        if let entry = DocumentController.docWindows.values.first {
            return entry.1
        }
        return nil
    }

    private func openWindow(with bitmap: Bitmap, filePath: String) -> String {
        let wc = WindowController()
        guard let pw = wc.window as? PigmentWindow else { return "" }
        let canvas = pw.canvasController
        canvas.state.bitmap = bitmap
        canvas.state.filePath = filePath
        canvas.state.dirty = false
        canvas.state.zoom = 100
        canvas.state.clearUndo()
        canvas.canvasView.bitmap = bitmap
        canvas.canvasView.needsDisplay = true

        // Wire tool controller and color state so canvas operations work in document windows
        canvas.toolController = toolController
        canvas.colorState = colorState

        if let tc = toolController {
            var opts = ToolOptions()
            opts.currentZoom = 100
            tc.options = opts
        }

        pw.title = URL(fileURLWithPath: filePath).lastPathComponent + " - Pigment"
        pw.makeKeyAndOrderFront(nil)

        let wid = "w\(DocumentController.nextDocWindowId)"
        DocumentController.nextDocWindowId += 1
        TestAPIWindowStore.shared.register(id: wid, window: pw)
        DocumentController.docWindows[wid] = (pw, canvas)
        DocumentController.docWindowOrder.append(wid)

        return wid
    }

    static func latestDocWindow() -> CanvasController? {
        guard let lastId = DocumentController.docWindowOrder.last else { return nil }
        return DocumentController.docWindows[lastId]?.1
    }
}

// MARK: - Routes
extension DocumentController: TestAPIControllerRoutes {

    static var routePrefix: String { "document" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/save") { [weak self] req in
            guard let self = self else { return .notFound(req) }

            struct SaveBody: Decodable {
                let windowId: String?
                let path: String
                let format: String
            }
            guard let b = try? JSONDecoder().decode(SaveBody.self, from: req.body) else {
                return .badRequest("body must be {\"path\":\"/abs/x.png\",\"format\":\"png|jpeg|bmp\"}")
            }

            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                let targetCanvas = CanvasController.findCanvas(windowId: b.windowId)
                guard let canvas = targetCanvas else {
                    result = .internalServerError("no canvas")
                    return
                }
                do {
                    try ImageWriter.write(bitmap: canvas.state.bitmap, format: b.format, path: b.path)
                    canvas.state.dirty = false
                    canvas.state.filePath = b.path
                    if let cgWin = (NSApp.keyWindow ?? NSApp.windows.first) as? PigmentWindow {
                        let fileName = URL(fileURLWithPath: b.path).lastPathComponent
                        cgWin.title = "\(fileName) - Pigment"
                    }
                    let body = try? JSONEncoder().encode(["ok": true])
                    result = .ok(json: body ?? Data())
                } catch ImageWriter.Error.unsupportedFormat(let fmt) {
                    let msg = "unsupported format: \(fmt)"
                    result = .ok(json: Data("{\"error\":\"\(msg)\"}".utf8))
                } catch {
                    result = .internalServerError(error.localizedDescription)
                }
            }
            return result ?? .internalServerError("no response")
        }

        router.post(prefix: Self.routePrefix, path: "/open") { [weak self] req in
            guard let self = self else { return .notFound(req) }

            struct OpenBody: Decodable {
                let path: String
            }
            guard let b = try? JSONDecoder().decode(OpenBody.self, from: req.body) else {
                return .badRequest("body must be {\"path\":\"/abs/x.png\"}")
            }

            guard let bitmap = ImageReader.read(from: b.path) else {
                let msg = "could not read image at path: \(b.path)"
                return .ok(json: Data("{\"error\":\"\(msg)\"}".utf8))
            }

            var windowId = ""
            DispatchQueue.main.sync {
                windowId = self.openWindow(with: bitmap, filePath: b.path)
            }

            if windowId.isEmpty {
                return .internalServerError("failed to open window")
            }

            let dict: [String: Any] = ["ok": true, "windowId": windowId]
            let body = try? JSONSerialization.data(withJSONObject: dict)
            return .ok(json: body ?? Data())
        }
    }
}
