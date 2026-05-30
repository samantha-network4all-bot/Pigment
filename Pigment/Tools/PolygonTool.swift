import AppKit

final class PolygonTool: Tool {
    var id: String { "polygon" }
    var cursor: NSCursor { .crosshair }

    private var vertices: [(Int, Int)] = []

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        vertices.append((x, y))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        guard let last = vertices.last else {
            vertices.append((x, y))
            return
        }
        drawEdge(&ctx, from: last, to: (x, y), lw: ctx.options.lineWidth, color: ctx.fgColor)
        vertices.append((x, y))
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        guard let last = vertices.last else {
            vertices.append((x, y))
            return
        }
        drawEdge(&ctx, from: last, to: (x, y), lw: ctx.options.lineWidth, color: ctx.fgColor)
        vertices.append((x, y))

        // Close the polygon: draw from last vertex back to first
        if vertices.count >= 3 {
            drawEdge(&ctx, from: vertices[vertices.count - 1], to: vertices[0],
                     lw: ctx.options.lineWidth, color: ctx.fgColor)
        }

        vertices.removeAll()
    }

    private func drawEdge(
        _ ctx: inout ToolContext,
        from: (Int, Int),
        to: (Int, Int),
        lw: Int,
        color: (UInt8, UInt8, UInt8)
    ) {
        if lw <= 1 {
            ctx.bitmap.drawLine(x0: from.0, y0: from.1, x1: to.0, y1: to.1, color: color)
            return
        }

        let dx = to.0 - from.0
        let dy = to.1 - from.1
        let len = Double(dx * dx + dy * dy).squareRoot()

        if len < 1 {
            let half = lw / 2
            for ody in -half..<(lw - half) {
                for odx in -half..<(lw - half) {
                    ctx.bitmap.setPixel(x: from.0 + odx, y: from.1 + ody, color: color)
                }
            }
            return
        }

        let nx = -Double(dy) / len
        let ny = Double(dx) / len
        let half = Double(lw - 1) / 2.0

        for i in 0..<lw {
            let offset = Double(i) - half
            let ox = Int(floor(nx * offset))
            let oy = Int(floor(ny * offset))
            ctx.bitmap.drawLine(
                x0: from.0 + ox, y0: from.1 + oy,
                x1: to.0 + ox, y1: to.1 + oy,
                color: color
            )
        }
    }
}
