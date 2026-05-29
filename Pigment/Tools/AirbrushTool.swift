import AppKit

struct AirbrushTool: Tool {
    var id: String { "airbrush" }
    var cursor: NSCursor { .crosshair }

    private let radii = [4, 8, 14]

    private func spray(ctx: inout ToolContext, px: Int, _ py: Int) {
        guard ctx.options.airbrushSize >= 1 && ctx.options.airbrushSize <= 3 else { return }
        let radius = radii[ctx.options.airbrushSize - 1]
        // Fill every pixel in the spray area for reliable coverage
        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy > radius * radius * 2 { continue }
                ctx.bitmap.setPixel(x: px + dx, y: py + dy, color: ctx.fgColor)
            }
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
