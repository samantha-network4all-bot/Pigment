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

            var response: TestAPIResponse?
            DispatchQueue.main.sync {
                let menu = NSApp.mainMenu
                guard let item = MenuController.findMenuItem(in: menu, path: b.path) else {
                    response = .notFound(req)
                    return
                }

                guard !item.isSeparatorItem else {
                    response = .conflict("separator")
                    return
                }

                guard item.isEnabled else {
                    response = .conflict("disabled")
                    return
                }

                if let action = item.action, let target = item.target {
                    _ = target.perform(action, with: item)
                } else if let action = item.action {
                    NSApp.sendAction(action, to: item.target, from: item)
                }

                let bodyData = try? JSONEncoder().encode(["ok": true])
                response = .ok(json: bodyData ?? Data())
            }
            return response ?? .internalServerError("no response")
        }
    }

    static func findMenuItem(in menu: NSMenu?, path: [String]) -> NSMenuItem? {
        guard let menu = menu, !path.isEmpty else { return nil }

        var currentMenu: NSMenu? = menu
        var items = currentMenu?.items ?? []

        for (index, title) in path.enumerated() {
            guard let match = items.first(where: { $0.title == title || $0.submenu?.title == title }) else { return nil }

            if index == path.count - 1 {
                return match
            }

            currentMenu = match.submenu
            items = currentMenu?.items ?? []
        }

        return nil
    }
}
