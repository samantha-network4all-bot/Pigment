import AppKit

final class EllipseTool: Tool {
    var id: String { "ellipse" }
    var cursor: NSCursor { .crosshair }

    private var startPoint: (Int, Int)?

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        startPoint = (Int(point.x.rounded()), Int(point.y.rounded()))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        // no-op: ellipse commits on pointerUp
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let (sx, sy) = startPoint else { return }
        let x0 = min(sx, Int(point.x.rounded()))
        let y0 = min(sy, Int(point.y.rounded()))
        let x1 = max(sx, Int(point.x.rounded()))
        let y1 = max(sy, Int(point.y.rounded()))

        let fillMode = ctx.options.fillMode
        let lw = ctx.options.lineWidth

        let cx = (x0 + x1) / 2
        let cy = (y0 + y1) / 2
        let a = (x1 - x0) / 2
        let b = (y1 - y0) / 2

        // Fill
        if fillMode == "fill" || fillMode == "outlineFill" {
            drawFill(ctx: &ctx, cx: cx, cy: cy, a: a, b: b)
        }

        // Outline
        if fillMode == "outline" || fillMode == "outlineFill" {
            drawOutline(ctx: &ctx, cx: cx, cy: cy, a: a, b: b, lw: lw)
        }

        startPoint = nil
    }

    private func drawFill(ctx: inout ToolContext, cx: Int, cy: Int, a: Int, b: Int) {
        guard a >= 0 && b >= 0 else { return }
        for y in (cy - b)...(cy + b) {
            let dy = Double(y - cy)
            let bb = Double(b) * Double(b)
            if bb == 0 { continue }
            let val = 1.0 - (dy * dy) / bb
            if val < 0 { continue }
            let dx = Int(Darwin.sqrt(val) * Double(a))
            let xStart = cx - dx
            let xEnd = cx + dx
            for x in xStart...xEnd {
                ctx.bitmap.setPixel(x: x, y: y, color: ctx.bgColor)
            }
        }
    }

    private func drawOutline(ctx: inout ToolContext, cx: Int, cy: Int, a: Int, b: Int, lw: Int) {
        if lw <= 0 { return }
        if lw == 1 {
            drawEllipseMidpoint(ctx: &ctx, cx: cx, cy: cy, a: a, b: b, color: ctx.fgColor)
        } else {
            let halfWidth = lw / 2
            for i in 0..<lw {
                var na = a + i - halfWidth
                var nb = b + i - halfWidth
                if na < 0 { na = 0 }
                if nb < 0 { nb = 0 }
                if na == 0 && nb == 0 {
                    ctx.bitmap.setPixel(x: cx, y: cy, color: ctx.fgColor)
                } else if na == 0 {
                    drawEllipseMidpoint(ctx: &ctx, cx: cx, cy: cy, a: 0, b: nb, color: ctx.fgColor)
                } else if nb == 0 {
                    drawEllipseMidpoint(ctx: &ctx, cx: cx, cy: cy, a: na, b: 0, color: ctx.fgColor)
                } else {
                    drawEllipseMidpoint(ctx: &ctx, cx: cx, cy: cy, a: na, b: nb, color: ctx.fgColor)
                }
            }
        }
    }

    private func drawEllipseMidpoint(ctx: inout ToolContext, cx: Int, cy: Int, a: Int, b: Int, color: (UInt8, UInt8, UInt8)) {
        // Midpoint ellipse algorithm (Bresenham) with 4-way symmetry
        guard a > 0 || b > 0 else {
            ctx.bitmap.setPixel(x: cx, y: cy, color: color)
            return
        }

        var x: Int64 = 0
        var y: Int64 = Int64(b)
        var a2: Int64 = Int64(a) * Int64(a)
        var b2: Int64 = Int64(b) * Int64(b)

        // Region 1
        var d1: Int64 = b2 - a2 * Int64(b) + a2 / 4
        var dx: Int64 = 0
        var dy: Int64 = 2 * a2 * y

        while dx < dy {
            plot4(cx: cx, cy: cy, x: Int(x), y: Int(y), ctx: &ctx, color: color)
            x += 1
            dx += 2 * b2
            if d1 < 0 {
                d1 += b2 + dx
            } else {
                y -= 1
                dy -= 2 * a2
                d1 += b2 + dx - dy
            }
        }

        // Region 2
        var d2: Int64 = b2 * (x + 1) * (x + 1) + a2 * (y - 1) * (y - 1) - a2 * b2
        while y >= 0 {
            plot4(cx: cx, cy: cy, x: Int(x), y: Int(y), ctx: &ctx, color: color)
            y -= 1
            dy -= 2 * a2
            if d2 > 0 {
                d2 += a2 - dy
            } else {
                x += 1
                dx += 2 * b2
                d2 += a2 - dy + dx
            }
        }
    }

    private func plot4(cx: Int, cy: Int, x: Int, y: Int, ctx: inout ToolContext, color: (UInt8, UInt8, UInt8)) {
        ctx.bitmap.setPixel(x: cx + x, y: cy + y, color: color)
        ctx.bitmap.setPixel(x: cx - x, y: cy + y, color: color)
        ctx.bitmap.setPixel(x: cx + x, y: cy - y, color: color)
        ctx.bitmap.setPixel(x: cx - x, y: cy - y, color: color)
    }
}
