import AppKit

struct AirbrushTool: Tool {
    var id: String { "airbrush" }
    var cursor: NSCursor { .crosshair }

    private let radii = [4, 8, 14]

    private func spray(ctx: inout ToolContext, px: Int, _ py: Int) {
        guard ctx.options.airbrushSize >= 1 && ctx.options.airbrushSize <= 3 else { return }
        let radius = radii[ctx.options.airbrushSize - 1]
        let count = radius * radius / 2
        for _ in 0..<count {
            let dx = Int.random(in: -radius...radius)
            let dy = Int.random(in: -radius...radius)
            if dx * dx + dy * dy > radius * radius { continue }
            ctx.bitmap.setPixel(x: px + dx, y: py + dy, color: ctx.fgColor)
        }
    }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        spray(ctx: &ctx, px: px, py)
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        spray(ctx: &ctx, px: px, py)
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        spray(ctx: &ctx, px: px, py)
    }
}
