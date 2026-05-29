import AppKit

final class MenuController: NSViewController {

    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }
}

// MARK: - Routes
extension MenuController: TestAPIControllerRoutes {

    static var routePrefix: String { "menu" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/invoke") { req in
            struct Body: Decodable {
                let path: [String]
            }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"path\":[\"Menu Item\",\"Sub Item\"]}")
            }

            let menu = NSApp.mainMenu
            guard let item = MenuController.findMenuItem(in: menu, path: b.path) else {
                return .notFound(req)
            }

            guard !item.isSeparatorItem else {
                return .conflict("separator")
            }

            guard item.isEnabled else {
                return .conflict("disabled")
            }

            DispatchQueue.main.async {
                if let action = item.action {
                    NSApp.sendAction(action, to: item.target, from: item)
                }
            }

            let bodyData = try? JSONEncoder().encode(["ok": true])
            return .ok(json: bodyData ?? Data())
        }
    }

    static func findMenuItem(in menu: NSMenu?, path: [String]) -> NSMenuItem? {
        guard let menu = menu, !path.isEmpty else { return nil }

        var currentMenu: NSMenu? = menu
        var items = currentMenu?.items ?? []

        for (index, title) in path.enumerated() {
            guard let match = items.first(where: { $0.title == title }) else { return nil }

            if index == path.count - 1 {
                return match
            }

            currentMenu = match.submenu
            items = currentMenu?.items ?? []
        }

        return nil
    }
}
