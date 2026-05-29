import AppKit

final class LineTool: Tool {
    var id: String { "line" }
    var cursor: NSCursor { .crosshair }

    private var startPoint: (Int, Int)?

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        startPoint = (Int(point.x.rounded()), Int(point.y.rounded()))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        // no-op: line commits on pointerUp
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let (sx, sy) = startPoint else { return }
        let x0 = sx
        let y0 = sy
        let x1 = Int(point.x.rounded())
        let y1 = Int(point.y.rounded())
        let lw = ctx.options.lineWidth
        let color = ctx.fgColor

        if lw <= 1 {
            ctx.bitmap.drawLine(x0: x0, y0: y0, x1: x1, y1: y1, color: color)
        } else {
            let dx = x1 - x0
            let dy = y1 - y0
            let len = Double(dx * dx + dy * dy).squareRoot()
            if len < 1 {
                drawThickPoint(ctx: &ctx, cx: x0, cy: y0, lw: lw, color: color)
                startPoint = nil
                return
            }
            // Perpendicular unit vector
            let nx = -Double(dy) / len
            let ny = Double(dx) / len
            let half = Double(lw - 1) / 2.0
            for i in 0..<lw {
                let offset = Double(i) - half
                let ox = Int((nx * offset).rounded())
                let oy = Int((ny * offset).rounded())
                ctx.bitmap.drawLine(x0: x0 + ox, y0: y0 + oy, x1: x1 + ox, y1: y1 + oy, color: color)
            }
        }
        startPoint = nil
    }

    private func drawThickPoint(ctx: inout ToolContext, cx: Int, cy: Int, lw: Int, color: (UInt8, UInt8, UInt8)) {
        let half = lw / 2
        for dy in -half..<(lw - half) {
            for dx in -half..<(lw - half) {
                ctx.bitmap.setPixel(x: cx + dx, y: cy + dy, color: color)
            }
        }
    }
}
