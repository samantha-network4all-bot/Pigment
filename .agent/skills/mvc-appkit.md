---
name: pigment-mvc-appkit
description: Pigment's architectural contract — every feature lives in an NSViewController that owns its model, its view, AND its HTTP test-API routes. Use this skill on every code-writing turn for the Pigment project.
---

# Pigment MVC for macOS / AppKit

This skill is **mandatory** for every code change to the Pigment
project. It defines how every feature is structured so that:

1. Business logic, UI, and orchestration are cleanly separated.
2. Every controller can be driven from the localhost HTTP test API
   without spawning a window or simulating input.
3. The feature-test harness in 007-builder probes features through
   a single uniform shape: `/<controller>/<action>`.

If your slice does not fit this shape, the slice is mis-spec'd —
write `state.json` with `{"action":"abort","reason":"non-mvc-slice"}`
and exit. Do not improvise.

---

## The three roles

### Model

- Plain Swift structs / classes in `Pigment/<Feature>/<Name>State.swift`.
- Holds data and business rules. No `import AppKit`. No `NSView`,
  no `NSWindow`, no `NSTextStorage` here.
- Examples: `CanvasState` (Bitmap + attributes + zoom + dirty + URL),
  `ColorState` (foreground + background + palette), `ToolOptions`.

### View

- An `NSView` subclass in `Pigment/<Feature>/<Name>View.swift`.
- Renders the model. Captures user gestures. Forwards them via
  delegate callbacks or `NSResponder` actions.
- Must not call AppKit panels (`NSOpenPanel`, `NSAlert`, …).
  Must not touch the test API. Must not own state that outlives
  itself.
- The canvas view draws the bitmap nearest-neighbor and routes pointer
  events to the active tool (PRD §8.2, §8.3). Only the Text tool's
  field uses `NSTextView`.

### Controller

- An `NSViewController` subclass in
  `Pigment/<Feature>/<Name>Controller.swift`.
- Owns one Model instance and one View instance.
- **Registers its HTTP routes** with the `TestAPIRouter` at
  `viewDidLoad`. This is the load-bearing part of the pattern.

---

## The controller-owns-route rule

This is the single most important contract in Pigment. Every
controller exposes a namespaced route prefix and registers every
endpoint that controller is responsible for.

### Required pattern

```swift
import AppKit

final class ColorController: NSViewController {

    let state = ColorState()           // model: fg/bg + palette (no AppKit imports)
    let colorBox: ColorBoxView

    init() {
        self.colorBox = ColorBoxView(frame: .zero)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = colorBox
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Wire the model → view binding here.
        colorBox.render(state)
        colorBox.delegate = self

        // REQUIRED: register routes for this controller's actions.
        TestAPIRouter.shared.register(controller: self)
    }
}

// Routes live in an extension next to the controller, NEVER in a
// separate file under TestAPI/. The controller owns its own API.
extension ColorController: TestAPIControllerRoutes {

    static var routePrefix: String { "color" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/state") { [weak self] _ in
            guard let self else { return .notFound }
            let body = try? JSONEncoder().encode(["fg": self.state.fgHex, "bg": self.state.bgHex])
            return .ok(json: body ?? Data())
        }
        router.post(prefix: Self.routePrefix, path: "/set") { [weak self] req in
            guard let self else { return .notFound }
            struct Body: Decodable { let fg: String?; let bg: String? }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"fg\"?:\"#RRGGBB\",\"bg\"?:\"#RRGGBB\"}")
            }
            DispatchQueue.main.sync { self.applyColors(fg: b.fg, bg: b.bg) }
            return .ok(json: Data(#"{"ok":true}"#.utf8))
        }
    }

    private func applyColors(fg: String?, bg: String?) {
        // model mutation + view binding; no panel, no recursion
        if let fg { state.fgHex = fg }
        if let bg { state.bgHex = bg }
        colorBox.render(state)
    }
}
```

### The router

The shared `TestAPIRouter` is a flat registry — controllers
register themselves into it, but each route ALWAYS sits in
`<routePrefix>/<path>`. The router never invents routes; it only
delegates.

```swift
final class TestAPIRouter {
    static let shared = TestAPIRouter()
    private var handlers: [String: (TestAPIRequest) -> TestAPIResponse] = [:]

    func register<C: TestAPIControllerRoutes>(controller: C) {
        controller.registerRoutes(on: self)
    }
    func get(prefix: String, path: String, _ h: @escaping (TestAPIRequest) -> TestAPIResponse) {
        handlers["GET /\(prefix)\(path)"] = h
    }
    func post(prefix: String, path: String, _ h: @escaping (TestAPIRequest) -> TestAPIResponse) {
        handlers["POST /\(prefix)\(path)"] = h
    }
    func dispatch(_ req: TestAPIRequest) -> TestAPIResponse {
        handlers["\(req.method) \(req.path)"] ?? .notFound(req)
    }
}

protocol TestAPIControllerRoutes {
    static var routePrefix: String { get }
    func registerRoutes(on router: TestAPIRouter)
}
```

### Required endpoints per controller

| Controller          | Prefix      | Min endpoints (PRD §7.3)                                       |
|---------------------|-------------|----------------------------------------------------------------|
| AppController       | (top-level) | `GET /healthz`, `POST /shutdown`, `GET /screenshot`           |
| WindowController    | `/window`   | `GET /list`, `GET /screenshot`                                 |
| CanvasController    | `/canvas`   | `POST /new`, `GET /state`, `GET /pixel`, `POST /click`, `POST /stroke`, `POST /resize` |
| ToolController      | `/tool`     | `POST /select`, `POST /options`, `GET /state`                 |
| ColorController     | `/color`    | `POST /set`, `GET /state`                                      |
| ZoomController      | `/zoom`     | `POST /set`, `POST /grid`                                      |
| DocumentController  | `/document` | `POST /open`, `POST /save`                                     |
| MenuController      | `/menu`     | `POST /invoke {path:[...]}`                                    |

A new feature MUST either:
- belong to an existing controller (add a route under the existing
  prefix), OR
- introduce a new controller with its own prefix + route file.

Never add a top-level route except the three orchestrator routes the
007-builder harness calls at fixed paths: `/healthz`, `/shutdown`, and
`/screenshot`. These live on `AppController` with no prefix; everything
else is namespaced under its controller.

---

## Project structure (canonical)

```
Pigment/
├── main.swift                              # NSApplication.shared.run()
├── AppDelegate.swift                       # instantiates AppController
│
├── App/
│   ├── AppController.swift                 # /healthz, /shutdown, /screenshot (top-level)
│   └── TestAPI/
│       ├── TestAPIServer.swift             # HTTP listener
│       ├── TestAPIRouter.swift             # flat registry
│       └── TestAPIRequest+Response.swift   # value types
│
├── Window/
│   ├── WindowController.swift              # /window/list
│   ├── WindowState.swift                   # model
│   └── PigmentWindow.swift                 # NSWindow subclass
│
├── Canvas/
│   ├── CanvasController.swift              # /canvas/*  (routes live here!)
│   ├── CanvasState.swift                   # Bitmap + attributes + zoom + dirty + URL
│   ├── Bitmap.swift                        # 24-bit RGB buffer (CG only, no AppKit)
│   └── CanvasView.swift                    # NSView: renders bitmap+overlay
│
├── Tools/
│   ├── ToolController.swift                # /tool/*
│   ├── ToolOptions.swift                   # model (no AppKit)
│   └── <Tool>Tool.swift …                  # one file per tool
│
├── Color/
│   ├── ColorController.swift               # /color/*
│   ├── ColorState.swift                    # model
│   └── ColorBoxView.swift
│
├── Document/
│   └── DocumentController.swift            # /document/*  (open, save)
│
├── Menu/
│   └── MenuController.swift                # /menu/invoke
│
└── Theme/                                  # Metrics, ColorHex (no controllers)
```

**Routes never live in their own file under `TestAPI/`.**
That was the old design and produced sprawling sidebar-of-routes
files. In the new design, finding where `POST /canvas/stroke` is
handled is one `grep -r "/stroke"` away — but actually it's the
CanvasController file by name, no grep needed.

---

## What this skill rejects

The orchestrator's quality check will block the PR on any of:

1. A route registered outside its controller. (e.g. `POST /canvas/stroke`
   declared in `Pigment/App/TestAPI/Routes.swift`.)
2. An `NSView` subclass that imports `Foundation.URLSession`,
   `TestAPIRouter`, or any TestAPI symbol. Views never speak API.
3. A controller without a `routePrefix` if it has any user-visible
   behavior.
4. A new top-level route (no controller prefix). Only the three
   orchestrator routes `/healthz`, `/shutdown`, `/screenshot` are
   exempt, and they live on `AppController`.
5. A `MainViewController` / `HomeViewController` / catch-all
   controller. One controller per *coherent feature*; if it grows
   past ~200 lines, decompose.
6. Model code that imports AppKit.
7. View code that holds `var state` that outlives the view's
   lifetime. Long-lived state belongs to the controller.

---

## Why this pattern (the rationale)

The previous notepad/ project taught us that the unit of testable
behavior is the controller, not the window. The reason is purely
operational: 007-builder's feature check fires HTTP probes; if a
behavior is reachable only by clicking the view, it's not testable
at all.

By forcing every controller to declare its own routes:

- The "what does this feature actually do?" question is answered in
  one file.
- The probe path is predictable (`/<prefix>/<action>`), so the
  planner can write acceptance JSON without reading code.
- Adding a feature means adding a controller, not weaving logic
  into a god-object.
- Code review can grep for controllers without routes and reject
  them automatically (the thermo-nuclear skill does exactly this).

---

## Workflow on each code-writing turn

1. Read the issue body. Identify which controller it touches
   (new or existing).
2. Open that controller file. If it doesn't exist, create it
   with the canonical scaffolding above.
3. Add the model field, the view binding, and the route registration
   *in the same file*.
4. If the acceptance probes name a new endpoint, the corresponding
   route handler exists in the SAME commit.
5. Build. Run feature test. Commit.

One slice = one controller + its routes + its model fields.
Resist the temptation to refactor adjacent controllers.
