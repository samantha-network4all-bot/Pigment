import AppKit

struct MagnifierTool: Tool {
    let id: String = "magnifier"
    var cursor: NSCursor { NSCursor.crosshair }

    private static let forwardCycle: [Int] = [100, 200, 600, 800]

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {}

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {}

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        let current = ctx.options.currentZoom
        let idx = Self.forwardCycle.firstIndex(of: current) ?? 0
        let next: Int
        if ctx.button == .secondary {
            // Backward: 100→800→600→200→100
            next = Self.forwardCycle[(idx - 1 + Self.forwardCycle.count) % Self.forwardCycle.count]
        } else {
            // Forward: 100→200→600→800→100
            next = Self.forwardCycle[(idx + 1) % Self.forwardCycle.count]
        }
        ctx.result = .zoom(next)
    }
}
