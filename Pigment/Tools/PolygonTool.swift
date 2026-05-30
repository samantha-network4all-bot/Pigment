import AppKit

final class PolygonTool: Tool {
    var id: String { "polygon" }
    var cursor: NSCursor { .crosshair }

    private var vertices: [(Int, Int)] = []

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        vertices.append((px, py))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard !vertices.isEmpty else { return }
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        let last = vertices[vertices.count - 1]
        if last.0 == px && last.1 == py { return }
        vertices.append((px, py))
        drawEdge(ctx: &ctx, from: last, to: (px, py))
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard !vertices.isEmpty else { return }
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        let last = vertices[vertices.count - 1]
        if last.0 != px || last.1 != py {
            vertices.append((px, py))
            drawEdge(ctx: &ctx, from: last, to: (px, py))
        }

        // Close the polygon: draw line from last vertex back to first
        if vertices.count >= 2 {
            let first = vertices[0]
            let lastVertex = vertices[vertices.count - 1]
            if first.0 != lastVertex.0 || first.1 != lastVertex.1 {
                drawEdge(ctx: &ctx, from: lastVertex, to: first)
            }
        }

        vertices.removeAll()
    }

    private func drawEdge(ctx: inout ToolContext, from: (Int, Int), to: (Int, Int)) {
        let lw = ctx.options.lineWidth
        let color = ctx.fgColor

        if lw <= 1 {
            ctx.bitmap.drawLine(x0: from.0, y0: from.1, x1: to.0, y1: to.1, color: color)
        } else {
            let dx = to.0 - from.0
            let dy = to.1 - from.1
            let len = Double(dx * dx + dy * dy).squareRoot()
            if len < 1 {
                drawThickPoint(ctx: &ctx, cx: to.0, cy: to.1, lw: lw, color: color)
                return
            }
            // Perpendicular unit vector
            let nx = -Double(dy) / len
            let ny = Double(dx) / len
            let halfWidth = lw / 2
            for i in 0..<lw {
                let offset = Double(i - halfWidth)
                let ox = Int((nx * offset).rounded())
                let oy = Int((ny * offset).rounded())
                ctx.bitmap.drawLine(x0: from.0 + ox, y0: from.1 + oy,
                                   x1: to.0 + ox, y1: to.1 + oy, color: color)
            }
        }
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
