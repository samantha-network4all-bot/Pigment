import AppKit

final class PolygonTool: Tool {
    var id: String { "polygon" }
    var cursor: NSCursor { .crosshair }

    private var vertices: [(Int, Int)] = []

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        vertices.append((Int(point.x.rounded()), Int(point.y.rounded())))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let last = vertices.last else { return }
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        drawEdge(&ctx, from: last, to: (x, y))
        vertices.append((x, y))
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let last = vertices.last else { return }
        let x = Int(point.x.rounded())
        let y: Int = Int(point.y.rounded())
        drawEdge(&ctx, from: last, to: (x, y))
        // Close the polygon: draw line from last vertex back to first
        if let first = vertices.first, vertices.count >= 2 {
            drawEdge(&ctx, from: (x, y), to: first)
        }
        vertices.removeAll()
    }

    private func drawEdge(_ ctx: inout ToolContext, from: (Int, Int), to: (Int, Int)) {
        let lw = ctx.options.lineWidth
        let color = ctx.fgColor
        if lw <= 1 {
            ctx.bitmap.drawLine(x0: from.0, y0: from.1, x1: to.0, y1: to.1, color: color)
        } else {
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
            let hw = lw / 2
            for i in -hw..<(lw - hw) {
                let ox = Int((nx * Double(i)).rounded())
                let oy = Int((ny * Double(i)).rounded())
                ctx.bitmap.drawLine(x0: from.0 + ox, y0: from.1 + oy,
                                   x1: to.0 + ox, y1: to.1 + oy,
                                   color: color)
            }
        }
    }
}
