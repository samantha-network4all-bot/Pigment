# PRD — Pigment (Windows XP Paint recreation, for macOS)

> **Audience:** an executor LLM ("Agent 007") building this app one
> vertical slice at a time, driven by the 007-builder orchestrator.
> Every design decision is pre-resolved. **Do not invent behavior,
> colors, sizes, tools, or libraries.** If something is unspecified,
> stop and ask the product owner.

---

## 0. Reading order

1. Read §1–§6 once, fully, before writing code.
2. Read **§7 (HTTP test API)** and **§8 (architectural invariants)**
   before *every* slice. The quality review enforces §8 mechanically;
   the feature check exercises §7.
3. Every feature you build MUST be reachable from the HTTP test API and
   MUST obey the MVC contract (§8.14 + `.agent/skills/mvc-appkit.md`).
   A behavior that can only be reached by clicking the UI is, for this
   project, untestable and therefore unbuilt.

---

## 1. Product Overview

### 1.1 What we are building
A native macOS app named **Pigment** that recreates the **features and
layout of Microsoft Paint from Windows XP** (`mspaint.exe` 5.1): a
16-tool raster bitmap editor with a left toolbox, a tool-options strip,
a 28-color palette, a sunken canvas, and a coordinate status bar.

Pigment is **faithful in layout and behavior** but **native in
styling** — standard macOS window chrome, the real macOS menu bar, and
native macOS controls/dialogs, not pixel-recreated XP 3D bevels.

### 1.2 In scope
- Left **toolbox** (16 tools), a **tool-options** strip beneath it, a
  bottom **color box** (28 swatches + foreground/background indicator),
  a central scrollable/zoomable **canvas** in a sunken well, and a
  **status bar**.
- All 16 XP tools with faithful behavior (§5).
- The XP menu set on the real macOS menu bar: **File, Edit, View,
  Image, Colors, Help** (§4.6).
- Foreground/background color model: primary click draws foreground,
  secondary click draws background; Eraser paints background.
- Image ops: Flip/Rotate, Stretch/Skew, Invert Colors, Attributes
  (resize/units), Clear Image, Draw Opaque.
- Selection (rectangular + free-form), cut/copy/paste, transparent vs
  opaque selection, move/stamp.
- Zoom (100/200/400/600/800%), Magnifier, Show Grid, Show Thumbnail,
  View Bitmap.
- Text tool with a Fonts toolbar (family/size/bold/italic/underline).
- File Open/Save/Save As for **PNG, JPEG, 24-bit BMP**; new files
  default to **PNG**.
- Print / Page Setup via the native macOS print system.
- 50-level undo/redo.
- An embedded localhost **HTTP test API** (§7) that drives every
  feature and returns PNG screenshots and pixel readback.

### 1.3 Out of scope
Layers / alpha channel / blend modes (the bitmap is opaque 24-bit RGB);
tabs; BMP depths other than 24-bit; GIF/TIFF; the pixel-faithful XP
"Edit Colors" dialog (use the native color picker); pixel-faithful XP
chrome; "Set As Desktop Background"; scanner/camera acquire; recent
files; dark mode; plugins; cloud/telemetry/auto-update; custom app icon.

### 1.4 Success criteria
A user can perform any drawing task XP Paint supports; the layout is
recognizably Paint; and **every feature is verifiable through the HTTP
test API by issuing commands and asserting on a screenshot or pixel
readback.**

---

## 2. Tech Stack (locked, do not deviate)

| Item | Choice |
| --- | --- |
| Language | Swift 5.9+ |
| UI framework | AppKit. SwiftUI permitted for option panels/controls; the **canvas is AppKit** (`NSView` drawing into a bitmap). |
| Project gen | **XcodeGen** (`Project.yml`). The `.xcodeproj` is generated each build and git-ignored. |
| Build | `xcodegen generate && xcodebuild -scheme Pigment -configuration Debug -derivedDataPath build/ build` |
| Min macOS | 13.0 |
| Architecture | Universal (arm64 + x86_64) |
| Third-party deps | **None.** Standard library, AppKit, SwiftUI, CoreGraphics, ImageIO, `Network.framework`. |
| HTTP server | Hand-rolled over `Network.framework` (`NWListener`). No web frameworks. |
| Image I/O | `NSBitmapImageRep` / ImageIO for PNG, JPEG, 24-bit BMP. |
| Entry point | Explicit `Pigment/main.swift` calling `NSApplication.shared.run()`. **No `@main`** (§8.1). |
| Window | Standard titled `NSWindow` with real traffic lights. |
| Bundle ID | `com.bimboware.pigment` |

---

## 3. Project Structure

Every user-visible feature is an `NSViewController` that owns its model,
its view, **and its HTTP routes** (§8.14, `.agent/skills/mvc-appkit.md`).
Routes live in an extension on the controller in the same file, never in
a shared routes file.

```
Pigment/
├── main.swift                          # NSApplication.shared.run()
├── AppDelegate.swift                   # instantiates AppController
│
├── App/
│   ├── AppController.swift             # /healthz, /shutdown, /screenshot
│   ├── MenuBuilder.swift               # builds the macOS menu bar
│   └── TestAPI/
│       ├── TestAPIServer.swift         # NWListener HTTP listener
│       ├── TestAPIRouter.swift         # flat registry; controllers register
│       └── TestAPIRequest+Response.swift
│
├── Window/
│   ├── WindowController.swift          # /window/list
│   ├── WindowState.swift
│   ├── PigmentWindow.swift             # NSWindow subclass
│   ├── RootView.swift                  # lays out toolbox/options/canvas/colorbox/status
│   └── StatusBarView.swift
│
├── Canvas/
│   ├── CanvasController.swift          # /canvas/*  (new, click, stroke, pixel, state, resize)
│   ├── CanvasState.swift               # Bitmap + Attributes + zoom + dirty + URL + format
│   ├── Bitmap.swift                    # 24-bit RGB buffer + draw primitives (no AppKit beyond CG)
│   ├── CanvasView.swift                # NSView: renders bitmap+overlay; routes pointer events
│   ├── CanvasScrollView.swift          # NSScrollView; sunken well
│   ├── Overlay.swift                   # temporary preview layer
│   ├── ZoomController.swift            # /zoom/* ; 100..800, grid, thumbnail
│   └── ThumbnailView.swift
│
├── Tools/
│   ├── ToolController.swift            # /tool/*  (select, options, state)
│   ├── ToolOptions.swift               # model (no AppKit)
│   ├── Tool.swift                      # protocol: down/drag/up, cursor
│   ├── ToolContext.swift               # bitmap, overlay, fg/bg, options
│   ├── PencilTool.swift  BrushTool.swift  AirbrushTool.swift  EraserTool.swift
│   ├── FillTool.swift  PickColorTool.swift  MagnifierTool.swift  TextTool.swift
│   ├── LineTool.swift  CurveTool.swift  RectangleTool.swift  RoundedRectangleTool.swift
│   ├── EllipseTool.swift  PolygonTool.swift  SelectRectTool.swift  SelectFreeFormTool.swift
│   └── ToolboxView.swift  ToolButton.swift  ToolOptionsView.swift
│
├── Color/
│   ├── ColorController.swift           # /color/*  (set, state)
│   ├── ColorState.swift                # fg/bg + palette (no AppKit)
│   ├── Palette.swift                   # 28 default swatches
│   ├── ColorBoxView.swift
│   └── ColorPickerBridge.swift         # drives NSColorPanel
│
├── Document/
│   ├── DocumentController.swift        # /document/*  (open, save)
│   ├── ImageReader.swift               # PNG/JPEG/BMP → Bitmap
│   └── ImageWriter.swift               # Bitmap → PNG/JPEG/24-bit BMP
│
├── Menu/
│   └── MenuController.swift            # /menu/invoke  (Image ops, Edit, View, undo/redo)
│
├── Selection/
│   ├── Selection.swift                 # region, floating pixels, transparent flag
│   └── (selection logic used by Select tools + MenuController clipboard ops)
│
└── Theme/
    ├── Metrics.swift                   # sizes, paddings (no controllers)
    └── ColorHex.swift                  # NSColor(hex:) helper
```

Do not create files outside this list without a controller home. Do not
add a top-level route (only the orchestrator routes `/healthz`,
`/shutdown`, `/screenshot` are top-level, §7.3).

---

## 4. Layout & Visual Specifications

1 image pixel = 1 logical point at 100% zoom; the bitmap is drawn
**nearest-neighbor / unsmoothed** so pixels are crisp when zoomed (§8.2).

### 4.1 Window layout
- Toolbox docks left, width `Metrics.toolboxWidth = 56` (2-column grid
  of 28×28pt tool cells).
- Tool-options strip directly below the toolbox, same width, height
  `Metrics.toolOptionsHeight = 80`.
- Color box docks along the bottom above the status bar, height
  `Metrics.colorBoxHeight = 48`, full width.
- Status bar bottom-most, height `Metrics.statusBarHeight = 22`.
- Canvas fills the center inside `CanvasScrollView`, a sunken gray well
  around the bitmap.

### 4.2 Metrics (`Theme/Metrics.swift`)
```swift
enum Metrics {
    static let toolboxWidth: CGFloat = 56
    static let toolCellSize: CGFloat = 28
    static let toolOptionsHeight: CGFloat = 80
    static let colorBoxHeight: CGFloat = 48
    static let statusBarHeight: CGFloat = 22
    static let swatchSize: CGFloat = 16
    static let fgbgIndicatorSize: CGFloat = 32
    static let canvasMargin: CGFloat = 6
    static let resizeHandleSize: CGFloat = 6
    static let defaultCanvas = NSSize(width: 800, height: 600)
    static let defaultWindowSize = NSSize(width: 1000, height: 720)
}
```

### 4.3 The 28-color palette (`Color/Palette.swift`)
2 rows of 14, in this exact order. Hex:
Row 1: `#000000 #808080 #800000 #808000 #008000 #008080 #000080 #800080 #808040 #004040 #0080FF #004080 #8000FF #804000`
Row 2: `#FFFFFF #C0C0C0 #FF0000 #FFFF00 #00FF00 #00FFFF #0000FF #FF00FF #FFFF80 #00FF80 #80FFFF #8080FF #FF0080 #FF8040`
- Default foreground `#000000`, background `#FFFFFF`.
- Primary-click swatch → foreground; secondary-click → background.
- Double-click a swatch / fg indicator, or Colors → Edit Colors →
  `NSColorPanel`.
- fg/bg indicator: two overlapping squares, fg top-left over bg.

### 4.4 Toolbox (16 tools), two columns, this exact order
Row1 Free-Form Select | Select(rect) · Row2 Eraser/Color Eraser | Fill ·
Row3 Pick Color | Magnifier · Row4 Pencil | Brush · Row5 Airbrush | Text ·
Row6 Line | Curve · Row7 Rectangle | Polygon · Row8 Ellipse | Rounded
Rectangle. Active tool cell shows a selected state; selecting updates the
options strip and the canvas cursor.

### 4.5 Status bar (`Window/StatusBarView.swift`)
Three left-aligned segments: (1) cursor `x,y` over the canvas (blank when
outside); (2) selection/shape `w x h` while dragging; (3) canvas `W x H`.

### 4.6 Menus (real macOS menu bar, `App/MenuBuilder.swift`)
App menu (`Pigment`): About Pigment, Quit. Then:
- **File**: New (⌘N) · Open… (⌘O) · Save (⌘S) · Save As… (⌘⇧S) · — · Page Setup… · Print… (⌘P) · — · Close Window (⌘W)
- **Edit**: Undo (⌘Z) · Redo (⌘⇧Z) · — · Cut (⌘X) · Copy (⌘C) · Paste (⌘V) · Clear Selection (⌫) · Select All (⌘A) · — · Copy To… · Paste From…
- **View**: Tool Box (✓) · Color Box (✓) · Status Bar (✓) · Text Toolbar (✓, only with Text tool) · — · Zoom ▸ (Normal 100% [⌘1] · Large 400% · Custom… 100/200/400/600/800 · Show Grid · Show Thumbnail) · — · View Bitmap (⌥⌘B)
- **Image**: Flip/Rotate… (⌃R) · Stretch/Skew… (⌃W) · Invert Colors (⌃I) · Attributes… (⌃E) · Clear Image (⌃⇧N) · — · Draw Opaque (✓)
- **Colors**: Edit Colors…
- **Help**: Help Topics · About Pigment

Items enable/disable contextually. Every menu item is invokable via
`POST /menu/invoke {"path":[...]}` (§7.3, §8.9).

---

## 5. Tool & Application Behavior

General (`Tools/Tool.swift`): tools get `pointerDown/Dragged/Up` with the
bitmap-space integer pixel and `button` (`.primary` / `.secondary`).
Primary draws foreground, secondary draws background unless overridden
(Eraser, Pick Color, Magnifier, selection). Freehand tools draw directly
to the bitmap with interpolation between samples (no gaps). Shapes/
selections preview on the overlay and composite into the bitmap on
`pointerUp`. One undo snapshot per committed operation (§8.15). Tool
output is **hard-edged, no anti-aliasing** (§8.16); Text uses normal
glyph rendering.

- **5.1 Pencil** — 1px hard dots, interpolated.
- **5.2 Brush** — shape grid (round ×3, square ×3, fwd-diag, back-diag); stamps along path.
- **5.3 Airbrush** — 3 radii; while down (even stationary) sprays random scatter ~20Hz, denser center.
- **5.4 Eraser / Color Eraser** — 4 square sizes; primary paints background; secondary replaces only foreground-colored pixels with background.
- **5.5 Fill** — 4-connected flood, exact color match; primary fg, secondary bg.
- **5.6 Pick Color** — primary→fg, secondary→bg, then revert to previous tool.
- **5.7 Magnifier** — 1×/2×/6×/8× → 100/200/600/800%, centered on click.
- **5.8 Text** — drag a frame; editable text in fg color; Fonts toolbar (family/size/B/I/U); transparent vs opaque (opaque fills frame with bg behind glyphs); committing rasterizes + one undo.
- **5.9 Line** — 5 widths; Shift constrains 0/45/90°.
- **5.10 Curve** — two-bend Bézier: drag segment, pull bend 1, pull bend 2 (third release commits).
- **5.11 Rectangle / Rounded / Ellipse** — fill modes: outline only / outline+fill / fill only; border uses line width; Shift = square/circle. Primary: border fg, fill bg; secondary swaps.
- **5.12 Polygon** — click vertices; double-click / click-near-start closes; Shift 45° segments.
- **5.13 Select (rect) & Free-Form** — floating selection; dragging moves it and fills the vacated area with bg; ⌥-drag duplicates; transparent toggle treats bg-colored pixels as see-through; Cut/Copy/Clear/Paste via `NSPasteboard` image data.
- **5.14 Image ops** (whole bitmap, or selection if present): Flip H/V, Rotate 90/180/270; Stretch H/V % (1–500), Skew H/V° (−89..89); Invert (255−v); Attributes (px/in/cm + DPI default 96; shrink crops right/bottom, grow pads with bg top-left anchored); Clear Image (fill bg); Draw Opaque toggle.
- **5.15 Canvas resize handles** — right-mid, bottom-mid, corner; drag crops/pads with bg; status size updates live; one undo on release.
- **5.16 Zoom/Grid/Thumbnail/View Bitmap** — zoom 100/200/400/600/800; nearest-neighbor; Show Grid only ≥400% (1px gray lines between pixels); Show Thumbnail floating window at 100%; View Bitmap fullscreen, any key/click exits.
- **5.17 Undo/Redo** — 50 full-bitmap snapshots; new op after undo truncates redo.

Foreground/background on macOS: primary (left) click draws fg; secondary
(right / two-finger) click draws bg. The test API carries `button`
explicitly so this is hardware-independent.

---

## 6. Dialogs (native)

- **6.1 Open / Save As** — `NSOpenPanel` / `NSSavePanel`; Save As accessory popup picks PNG (default) / JPEG / 24-bit BMP; JPEG quality 0.9. Test API bypasses panels (§7.3 `/document/*`).
- **6.2 Page Setup / Print** — `NSPageLayout` / `NSPrintOperation` over a view drawing the bitmap scaled to the page.
- **6.3 Attributes** — native sheet: Width/Height, Units (px/in/cm), DPI (default 96), OK/Cancel/Default.
- **6.4 Flip/Rotate** — native sheet: Flip H / Flip V / Rotate 90/180/270.
- **6.5 Stretch/Skew** — native sheet: Stretch H/V % (default 100), Skew H/V° (default 0).
- **6.6 Edit Colors** — `NSColorPanel`.
- **6.7 About / Help Topics** — panel: `Pigment`, `Version 1.0`, `A faithful Windows XP Paint recreation for macOS.`, `© 2026 Bimboware`.
- **6.8 Close prompt** — dirty-window close uses `NSAlert`: Save / Don't Save / Cancel.

---

## 7. Testability (the HTTP test API)

### 7.1 Why
Headless verification was the biggest failure mode of prior projects.
`osascript` / `CGEvent` synthetic input silently no-ops without
Accessibility permission, and harnesses saw that as "passed". Pigment's
contract: **every product behavior MUST be reachable via an HTTP endpoint
on `127.0.0.1`.** The feature check uses HTTP only — never `osascript`,
`CGEvent`, or `AXUIElement`.

### 7.2 Enabling the API
- The server binds when `PIGMENT_TEST_API=1` is in the environment.
  Default off.
- The port is OS-chosen (bind to `:0`) and written to
  `~/Library/Application Support/Pigment/test-api.port` (decimal,
  newline-terminated) **before** the listener accepts connections.
- The server runs on a background queue; handlers dispatch to the main
  queue before touching AppKit / the bitmap (§8.12).
- All canvas coordinates in requests/responses are **bitmap pixels**
  (origin top-left), independent of zoom.

### 7.3 Required endpoints
Organised by the owning controller (`.agent/skills/mvc-appkit.md`).
Every route is `/<prefix>/<action>`; the only top-level routes are the
three orchestrator routes `/healthz`, `/shutdown`, `/screenshot`. JSON
unless noted; errors return `{"error":"..."}` with a 4xx/5xx.

#### App (`AppController`) — the three orchestrator top-level routes
These three are **top-level** (no controller prefix) because the
007-builder harness calls them at fixed paths: it polls `/healthz`,
captures `/screenshot` after every attempt, and POSTs `/shutdown` to
stop the app. They are the only permitted top-level routes (§8.14).
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| GET | `/healthz` | — | `{"ok":true}` | Readiness probe |
| POST | `/shutdown` | — | `{"ok":true}` | `NSApp.terminate(nil)` after responding |
| GET | `/screenshot` | `?windowId=w1&region=window\|canvas` (defaults: key window, `window`) | `image/png` | `window`=contentView PNG (§7.6); `canvas`=bitmap at 100%. In-process only (§8.13). The orchestrator calls this with no query for visual proof. |

#### Window (`WindowController`)
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| GET | `/window/list` | — | `[{"id":"w1","title":"untitled - Pigment","isKey":true}]` | Window inventory |

#### Canvas (`CanvasController`)
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| POST | `/canvas/new` | `{"w":800,"h":600}` (optional) | `{"ok":true,"windowId":"w2"}` | New untitled document |
| GET | `/canvas/state` | `?windowId=w1` | `{"canvas":{"w":800,"h":600},"zoom":100,"dirty":false,"filePath":null,"drawOpaque":true,"selection":null}` | Document/canvas state |
| GET | `/canvas/pixel` | `?windowId=w1&x=&y=` | `{"x":10,"y":10,"color":"#RRGGBB"}` | Read one bitmap pixel |
| POST | `/canvas/click` | `{"x":10,"y":10,"button":"left\|right","windowId":"w1"}` | `{"ok":true}` | Single pointer down+up with the active tool |
| POST | `/canvas/stroke` | `{"points":[[x,y],...],"button":"left\|right","windowId":"w1"}` | `{"ok":true}` | down at points[0], drag through rest, up at last |
| POST | `/canvas/resize` | `{"w":400,"h":300,"windowId":"w1"}` | `{"ok":true}` | Crop/pad with background |

#### Tool (`ToolController`)
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| POST | `/tool/select` | `{"tool":"pencil"}` | `{"ok":true}` | ids: `freeform-select,select,eraser,fill,pick-color,magnifier,pencil,brush,airbrush,text,line,curve,rectangle,polygon,ellipse,rounded-rectangle` |
| POST | `/tool/options` | `{"brushSize":3,"lineWidth":2,"fillMode":"outlineFill","eraserSize":4,"airbrushSize":2,"transparentSelection":false}` | `{"ok":true}` | Set current-tool options |
| GET | `/tool/state` | — | `{"tool":"pencil","options":{...}}` | Active tool + options |

#### Color (`ColorController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| POST | `/color/set` | `{"fg":"#RRGGBB","bg":"#RRGGBB"}` (either) | `{"ok":true}` | Set foreground/background |
| GET | `/color/state` | — | `{"fg":"#000000","bg":"#FFFFFF"}` | Current colors |

#### Zoom (`ZoomController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| POST | `/zoom/set` | `{"percent":400,"windowId":"w1"}` | `{"ok":true}` | Set zoom (100/200/400/600/800) |
| POST | `/zoom/grid` | `{"on":true,"windowId":"w1"}` | `{"ok":true}` | Toggle Show Grid |

#### Document (`DocumentController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| POST | `/document/open` | `{"path":"/abs/x.png"}` | `{"ok":true,"windowId":"w2"}` | Open file, bypass NSOpenPanel |
| POST | `/document/save` | `{"windowId":"w1","path":"/abs/x.png","format":"png\|jpeg\|bmp"}` | `{"ok":true}` | Save, bypass NSSavePanel |

#### Menu (`MenuController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| POST | `/menu/invoke` | `{"path":["Image","Invert Colors"]}` | `{"ok":true}` | Invoke a menu item by title path. Walks `NSApp.mainMenu`. 409 on separator/disabled. Covers Edit (undo/redo/cut/copy/paste/clear/select-all), Image (flip/rotate/stretch-skew/invert/attributes/clear/draw-opaque), View. |

New controllers MAY add prefixes. New behavior MUST belong to a
controller — never a top-level route (quality review blocks it).

### 7.4 Per-issue contract
Each `slice` issue body carries an `acceptance:` JSON block of HTTP
probes. Example for "draw with pencil":
```json
{
  "acceptance": [
    {"step": "pencil-draws-black",
     "calls": [
       {"method":"POST","path":"/tool/select","body":{"tool":"pencil"}},
       {"method":"POST","path":"/color/set","body":{"fg":"#000000"}},
       {"method":"POST","path":"/canvas/stroke","body":{"points":[[10,10],[100,10]],"button":"left"}},
       {"method":"GET","path":"/canvas/pixel?x=50&y=10","expect":{"color":"#000000"}}
     ]}
  ]
}
```
The feature check fails the issue if any `expect` assertion fails.

### 7.5 Security
Binds only to `127.0.0.1`, no auth, opt-in via `PIGMENT_TEST_API=1`
(an env var, not a build flag), so shipped binaries stay inert by default.

### 7.6 Self-screenshot
`/screenshot` renders the target (key by default) window's `contentView`
to PNG using **in-process drawing only**:
```swift
guard let win = lookupWindow(id) else { /* 404 */ }
let view = win.contentView!
let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
view.cacheDisplay(in: view.bounds, to: rep)
let png = rep.representation(using: .png, properties: [:])!
```
For `region=canvas`, export the `Bitmap` directly to PNG at 100%.
It MUST NOT call `CGWindowListCreateImage`, `CGDisplayCreateImage`,
`NSScreen` pixel grabs, or shell out to `screencapture` (all require
TCC permission and silently degrade to no-op). `/screenshot` must work
the moment `PIGMENT_TEST_API=1` is set, with zero permission prompts.

---

## 8. Architectural invariants

Extracted from `lessons-learned.md`. The code-quality review uses this
list as its checklist; any violation blocks the PR.

### 8.1 Entry point
Explicit `Pigment/main.swift` constructs `NSApplication.shared`, assigns
the delegate, calls `setActivationPolicy(.regular)`, and `app.run()`.
`@main` on an `NSApplicationDelegate` subclass is forbidden.

### 8.2 Bitmap model
The document is a single flat **opaque 24-bit RGB** `Bitmap` — no
layers, no alpha channel. Tools mutate the `Bitmap`; in-progress
shapes/selections live on the `Overlay` and composite down on commit.
The canvas renders the bitmap **nearest-neighbor / unsmoothed** at all
zooms. A PR that introduces layers, an alpha channel, or smoothed/
anti-aliased scaling of the bitmap is a review failure.

### 8.3 Canvas input mapping & first responder
`CanvasView` is the first responder for drawing, not its enclosing
`NSScrollView`. Pointer points MUST be converted to **integer bitmap
pixels** correctly for the current zoom and scroll offset before being
handed to a tool. The same mapping path serves both real pointer events
and `/canvas/click` + `/canvas/stroke` (§8.9).

### 8.4 Image loading
`NSImage(imageLiteralResourceName:)` is forbidden. Use failable
`NSImage(named:)` with a non-trapping fallback.

### 8.5 Callback re-entrancy
A method that "sets the current tool / color / selection" updates visual
state only. It MUST NOT emit the user-action callback the rest of the app
uses to *request* that same change (no notification feedback loops).

### 8.6 Window
The main window is a standard titled `NSWindow` with real traffic lights.
Title format `"<filename or 'untitled'> - Pigment"`. Any `NSWindow`
subclass that sets `.borderless` MUST override `canBecomeKey` /
`canBecomeMain` (not expected in v1, but enforced if present).

### 8.7 File panels & dialogs
File open/save uses `NSOpenPanel` / `NSSavePanel`; Image transform
dialogs and Edit Colors use native sheets / `NSColorPanel`. No custom
file browser. The test API reaches file I/O through `/document/*`,
bypassing the panels entirely (so file ops are testable headlessly).

### 8.8 Force-unwrap discipline
`try!`, `as!`, and `!`-on-optionals are forbidden except:
`NSScreen.main` (guard + fallback); `URL(string:)` of compile-time
literals; the `bitmapImageRepForCachingDisplay`/`representation(using:)`
pair in the screenshot path (§7.6) where failure is unreachable.

### 8.9 Test API parity
Every PR adding user-visible behavior MUST extend the owning
controller's routes so the behavior is reachable via HTTP. A new tool
without `/tool/select` support, a new menu command not reachable via
`/menu/invoke`, or a new transform with no probe path fails review.

### 8.10 Silent failure
`catch { /* ignore */ }` is forbidden. Errors propagate or surface an
`NSAlert` on the main queue.

### 8.11 Notifications & observers
Closures stored by `NotificationCenter` capture `self` weakly. Strong
self-captures in stored observer closures are PR-blockers.

### 8.12 Main-queue dispatch from background
Test API handlers run on a background queue; touching AppKit or the
bitmap goes through `DispatchQueue.main.sync`. Never touch AppKit from
the background queue directly.

### 8.13 Self-screenshot only
`/screenshot` uses only the in-process path in §7.6. Any reach
for `CGWindowListCreateImage`, `CGDisplayCreateImage`, `screencapture`,
or any TCC-gated API is a blocker. It must work first-try with no
permission prompts.

### 8.14 Controller owns its routes (MVC)
Every user-visible feature lives in an `NSViewController` under
`Pigment/<Feature>/<Name>Controller.swift`. The controller registers its
own routes by conforming to `TestAPIControllerRoutes` and calling
`TestAPIRouter.shared.register(controller: self)` in `viewDidLoad`.
Route handlers live in an extension on the controller in the same file —
never in a shared routes file. Views (`NSView` subclasses) MUST NOT
reference `TestAPIRouter`, `URLSession`, or HTTP types. Models (plain
Swift) MUST NOT `import AppKit`. Endpoints are namespaced under the
controller prefix; top-level routes are forbidden except the three
orchestrator routes `/healthz`, `/shutdown`, `/screenshot`.
The full pattern and the required-endpoints-by-controller table live in
`.agent/skills/mvc-appkit.md`; the quality review enforces it.

### 8.15 Undo discipline
`Canvas/CanvasState` owns a 50-deep snapshot undo stack. Every committed
mutation (a freehand stroke on release, a shape/selection commit, a fill,
an Image transform, a paste, a clear, a canvas resize) pushes exactly one
snapshot. A new mutation after undo truncates the redo branch.

### 8.16 Hard-edged drawing
Tool output replaces pixels with exact colors — no anti-aliasing, no
alpha blending — matching Paint's hard edges. Only the Text tool uses the
system's normal glyph rendering. Flood fill is exact-match, 4-connected.

---

## 9. The orchestrator's contract
(Informational; not implemented by coding agents.)
- Issues are labelled `slice`, numbered `S1`, `S2`, …
- `S1` ≈ "app launches via `main.swift`, shows a window with an 800×600
  white canvas, `GET /healthz` → 200, `GET /window/list` → one entry,
  `GET /screenshot` → a PNG."
- `next-issue` reads §1–§6 + closed slices to propose the next smallest
  vertical slice; each carries an `acceptance:` block (§7.4) and extends
  the test API (§8.9).
- Each issue cycles `code-agent → xcodebuild → feature-test →
  quality-review`; failure bumps `attempt:N`; at the cap the orchestrator
  hands off for human review.

---

## 10. Out of v1, deferred
Layers; non-24-bit BMP depths; GIF/TIFF; pixel-faithful XP chrome and
Edit Colors dialog; desktop-background setter; acquire from scanner/
camera; recent files; dark mode; custom app icon; print preview beyond
the native sheet.

End of PRD.
