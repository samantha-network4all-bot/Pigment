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
        }
        drawCurve(&ctx, current: pt)
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let _ = start, let _ = bend1, let _ = bend2 else {
            return
        }
        let pt = (Int(point.x.rounded()), Int(point.y.rounded()))
        drawCurve(&ctx, current: pt)
        start = nil
        bend1 = nil
        bend2 = nil
    }

    private func drawCurve(_ ctx: inout ToolContext, current: (Int, Int)) {
        guard let (x0, y0) = start,
              let (x1, y1) = bend1,
              let (x2, y2) = bend2 else { return }

        let x3 = current.0
        let y3 = current.1

        // Cubic Bézier: P0=start, P1=bend1, P2=bend2, P3=current
        let p0x = Double(x0), p0y = Double(y0)
        let p1x = Double(x1), p1y = Double(y1)
        let p2x = Double(x2), p2y = Double(y2)
        let p3x = Double(x3), p3y = Double(y3)

        let color = ctx.fgColor
        let lw = ctx.options.lineWidth
        let steps = 200

        var prev = (x0, y0)
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let u = 1.0 - t
            let tt = t * t
            let uu = u * u
            let uuu = uu * u
            let ttt = tt * t

            let px = uuu * p0x + 3.0 * uu * t * p1x + 3.0 * u * tt * p2x + ttt * p3x
            let py = uuu * p0y + 3.0 * uu * t * p1y + 3.0 * u * tt * p2y + ttt * p3y
            let curr = (Int(px.rounded()), Int(py.rounded()))

            if lw <= 1 {
                ctx.bitmap.drawLine(x0: prev.0, y0: prev.1, x1: curr.0, y1: curr.1, color: color)
            } else {
                let dx = curr.0 - prev.0
                let dy = curr.1 - prev.1
                let len = Double(dx * dx + dy * dy).squareRoot()
                if len < 1 {
                    let half = lw / 2
                    for ody in -half..<(lw - half) {
                        for odx in -half..<(lw - half) {
                            ctx.bitmap.setPixel(x: prev.0 + odx, y: prev.1 + ody, color: color)
                        }
                    }
                } else {
                    let nx = -Double(dy) / len
                    let ny = Double(dx) / len
                    let half = Double(lw - 1) / 2.0
                    for j in 0..<lw {
                        let offset = Double(j) - half
                        let ox = Int((nx * offset).rounded())
                        let oy = Int((ny * offset).rounded())
                        ctx.bitmap.drawLine(x0: prev.0 + ox, y0: prev.1 + oy,
                                           x1: curr.0 + ox, y1: curr.1 + oy,
                                           color: color)
                    }
                }
            }
            prev = curr
        }
    }
}
