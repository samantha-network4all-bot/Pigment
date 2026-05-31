import AppKit

final class DocumentController: NSViewController {

    // Retained references to document windows so test API can find them
    private static var nextDocWindowId = 2
    // Map windowId -> (window, canvasController)
    private static var docWindows: [String: (PigmentWindow, CanvasController)] = [:]

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
        // Fallback: check doc windows
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

        if let tc = canvas.toolController {
            var opts = ToolOptions()
            opts.currentZoom = 100
            tc.options = opts
        }

        pw.title = URL(fileURLWithPath: filePath).lastPathComponent + " - Pigment"

        let wid = "w\(DocumentController.nextDocWindowId)"
        DocumentController.nextDocWindowId += 1
        TestAPIWindowStore.shared.register(id: wid, window: pw)
        DocumentController.docWindows[wid] = (pw, canvas)

        wc.showWindow(nil)
        return wid
    }

    private static func clearDocWindows() {
        docWindows.removeAll()
    }
}

// MARK: - Routes
extension DocumentController: TestAPIControllerRoutes {

    static var routePrefix: String { "document" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/save") { [weak self] req in
            guard let self = self else { return .notFound(req) }

            struct Body: Decodable {
                let windowId: String?
                let path: String
                let format: String
            }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"path\":\"/abs/x.png\",\"format\":\"png|jpeg|bmp\"}")
            }

            guard ImageWriter.Format(rawValue: b.format) != nil else {
                return .badRequest("unsupported format: \(b.format)")
            }

            var result: TestAPIResponse?
            DispatchQueue.main.sync {
                let targetWindowId: String?
                if let wid = b.windowId, !wid.isEmpty {
                    targetWindowId = wid
                } else {
                    targetWindowId = nil
                }

                var targetCanvas: CanvasController?
                if let wid = targetWindowId {
                    if let entry = DocumentController.docWindows[wid] {
                        targetCanvas = entry.1
                    } else if let win = TestAPIWindowStore.shared.window(id: wid) as? PigmentWindow {
                        targetCanvas = win.canvasController
                    }
                }
                if targetCanvas == nil {
                    targetCanvas = self.keyCanvasController()
                }

                guard let canvas = targetCanvas else {
                    result = .internalServerError("no canvas")
                    return
                }

                let ok = ImageWriter.write(bitmap: canvas.state.bitmap, format: b.format, path: b.path)
                if ok {
                    canvas.state.dirty = false
                    canvas.state.filePath = b.path
                    if let win = (TestAPIWindowStore.shared.window(id: targetWindowId) ??
                                  (NSApp.keyWindow ?? NSApp.windows.first)) {
                        let fileName = URL(fileURLWithPath: b.path).lastPathComponent
                        win.title = "\(fileName) - Pigment"
                    }
                    if let body = try? JSONEncoder().encode(["ok": true]) {
                        result = .ok(json: body)
                    } else {
                        result = .internalServerError("JSON encode failed")
                    }
                } else {
                    result = .badRequest("unsupported format or write failed")
                }
            }
            return result ?? .internalServerError("no response")
        }

        router.post(prefix: Self.routePrefix, path: "/open") { [weak self] req in
            guard let self = self else { return .notFound(req) }

            struct Body: Decodable {
                let path: String
            }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"path\":\"/abs/x.png\"}")
            }

            // Read from disk on background thread before dispatching to main
            guard let bitmap = ImageReader.read(from: b.path) else {
                return .badRequest("could not read image at path: \(b.path)")
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
