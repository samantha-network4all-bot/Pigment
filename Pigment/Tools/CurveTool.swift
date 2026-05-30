import AppKit

final class CurveTool: Tool {
    var id: String { "curve" }
    var cursor: NSCursor { .crosshair }

    private var start: (Int, Int)?
    private var bend1: (Int, Int)?
    private var bend2: (Int, Int)?

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        start = (Int(point.x.rounded()), Int(point.y.rounded()))
        bend1 = nil
        bend2 = nil
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let _ = start else { return }
        let pt = (Int(point.x.rounded()), Int(point.y.rounded()))

        if bend1 == nil {
            bend1 = pt
        } else if bend2 == nil {
            bend2 = pt
            // First time bend2 is set, draw preview with current point as endpoint
            drawCurve(&ctx, endPt: pt)
        } else {
            bend2 = pt
            // Update bend2 and redraw preview with current point as endpoint
            drawCurve(&ctx, endPt: pt)
        }
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let _ = start, let _ = bend1, let _ = bend2 else {
            // Not all three set yet: no-op (waiting for more drags)
            return
        }
        let pt = (Int(point.x.rounded()), Int(point.y.rounded()))
        // Commit the curve with the final endpoint
        bend2 = pt
        drawCurve(&ctx, endPt: pt)
        start = nil
        bend1 = nil
        bend2 = nil
    }

    private func drawCurve(_ ctx: inout ToolContext, endPt: (Int, Int)) {
        guard let (x0, y0) = start,
              let (x1, y1) = bend1,
              let (x2, y2) = bend2 else { return }

        // Cubic Bézier: P0=start, P1=bend1, P2=bend2, P3=endPt
        let p0 = (Double(x0), Double(y0))
        let p1 = (Double(x1), Double(y1))
        let p2 = (Double(x2), Double(y2))
        let p3 = (Double(endPt.0), Double(endPt.1))

        let color = ctx.fgColor
        let lw = ctx.options.lineWidth

        // Generate parametric points with step 0.01
        var points: [(Int, Int)] = []
        var t: Double = 0.0
        while t <= 1.0 {
            let u = 1.0 - t
            let tt = t * t
            let uu = u * u
            let uuu = uu * u
            let ttt = tt * t

            let px = uuu * p0.0 + 3.0 * uu * t * p1.0 + 3.0 * u * tt * p2.0 + ttt * p3.0
            let py = uuu * p0.1 + 3.0 * uu * t * p1.1 + 3.0 * u * tt * p2.1 + ttt * p3.1

            points.append((Int(px.rounded()), Int(py.rounded())))
            t += 0.01
        }

        // Draw line between consecutive parametric points
        if lw <= 1 {
            for i in 0..<(points.count - 1) {
                ctx.bitmap.drawLine(
                    x0: points[i].0, y0: points[i].1,
                    x1: points[i + 1].0, y1: points[i + 1].1,
                    color: color
                )
            }
        } else {
            // For lineWidth > 1, draw the curve at width-1 offset
            // Use perpendicular offset approach (same as LineTool)
            guard points.count >= 2 else {
                if let p = points.first {
                    let half = lw / 2
                    for dy in -half..<(lw - half) {
                        for dx in -half..<(lw - half) {
                            ctx.bitmap.setPixel(x: p.0 + dx, y: p.1 + dy, color: color)
                        }
                    }
                }
                return
            }

            // Draw thick curve: for each segment between parametric points,
            // compute perpendicular and draw offset lines
            for i in 0..<(points.count - 1) {
                let sx = points[i].0
                let sy = points[i].1
                let ex = points[i + 1].0
                let ey = points[i + 1].1
                let dx = ex - sx
                let dy = ey - sy
                let len = Double(dx * dx + dy * dy).squareRoot()
                if len < 1 {
                    let half = lw / 2
                    for ody in -half..<(lw - half) {
                        for odx in -half..<(lw - half) {
                            ctx.bitmap.setPixel(x: sx + odx, y: sy + ody, color: color)
                        }
                    }
                    continue
                }
                let nx = -Double(dy) / len
                let ny = Double(dx) / len
                let half = Double(lw - 1) / 2.0
                for j in 0..<lw {
                    let offset = Double(j) - half
                    let ox = Int((nx * offset).rounded())
                    let oy = Int((ny * offset).rounded())
                    ctx.bitmap.drawLine(
                        x0: sx + ox, y0: sy + oy,
                        x1: ex + ox, y1: ey + oy,
                        color: color
                    )
                }
            }
        }
    }
}
