import AppKit

final class ColorController: NSViewController {

    var colorState: ColorState

    init(colorState: ColorState) {
        self.colorState = colorState
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
}

// MARK: - Routes
extension ColorController: TestAPIControllerRoutes {

    static var routePrefix: String { "color" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/set") { [weak self] req in
            guard let self else { return .notFound(req) }
            struct Body: Decodable { let fg: String?; let bg: String? }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"fg\"?:\"#RRGGBB\",\"bg\"?:\"#RRGGBB\"}")
            }
            DispatchQueue.main.sync {
                if let fg = b.fg { self.colorState.setForeground(fg) }
                if let bg = b.bg { self.colorState.setBackground(bg) }
            }
            let json = try? JSONEncoder().encode(["ok": true])
            return .ok(json: json ?? Data())
        }

        router.get(prefix: Self.routePrefix, path: "/state") { [weak self] req in
            guard let self else { return .notFound(req) }
            var result: [String: String] = [:]
            DispatchQueue.main.sync {
                let (fr, fg, fb) = self.colorState.fgColor
                let (br, bg, bb) = self.colorState.bgColor
                result["fg"] = String(format: "#%02X%02X%02X", fr, fg, fb)
                result["bg"] = String(format: "#%02X%02X%02X", br, bg, bb)
            }
            guard let json = try? JSONSerialization.data(withJSONObject: result) else {
                return .internalServerError("JSON encode failed")
            }
            return .ok(json: json)
        }
    }
}
