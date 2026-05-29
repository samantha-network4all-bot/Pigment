import AppKit

struct AirbrushTool: Tool {
    let id: String = "airbrush"
    var cursor: NSCursor { .crosshair }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        spray(ctx: &ctx, at: point)
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        spray(ctx: &ctx, at: point)
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        spray(ctx: &ctx, at: point)
    }

    private func spray(ctx: inout ToolContext, at point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        let size = max(1, min(ctx.options.airbrushSize, 3))
        let radii: [Int] = [6, 12, 18]
        let radius = radii[size - 1]

        // Spray: scatter fgColor pixels within the circle radius.
        // Iterates the bounding box in a deterministic order;
        // circle check and bounds check handled by setPixel.
        let r2 = radius * radius
        for dy in -radius...radius {
            for dx in -radius...radius {
                guard dx * dx + dy * dy <= r2 else { continue }
                ctx.bitmap.setPixel(x: px + dx, y: py + dy, color: ctx.fgColor)
            }
        }
    }
}
