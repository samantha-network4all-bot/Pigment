import AppKit

struct MagnifierTool: Tool {
    let id: String = "magnifier"
    var cursor: NSCursor { NSCursor.crosshair }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        let levels = [100, 200, 400, 600, 800]
        let current = ctx.options.magnifierZoom
        let idx = levels.firstIndex(of: current) ?? 0
        let next = levels[(idx + 1) % levels.count]
        ctx.result = .zoom(next)
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {}

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {}
}
