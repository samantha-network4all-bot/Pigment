import AppKit

final class RoundedRectangleTool: Tool {
    var id: String { "rounded-rectangle" }
    var cursor: NSCursor { .crosshair }

    private var startPoint: (Int, Int)?

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        startPoint = (Int(point.x.rounded()), Int(point.y.rounded()))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        // no-op: rounded rectangle commits on pointerUp
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let (sx, sy) = startPoint else { return }
        let x0 = min(sx, Int(point.x.rounded()))
        let y0 = min(sy, Int(point.y.rounded()))
        let x1 = max(sx, Int(point.x.rounded()))
        let y1 = max(sy, Int(point.y.rounded()))

        let w = x1 - x0
        let h = y1 - y0
        let r = min(w, h) / 4

        let fillMode = ctx.options.fillMode
        let lw = ctx.options.lineWidth
        let halfWidth = lw / 2

        // Right-click with outlineFill: fill interior with bgColor, no border.
        if ctx.button == .secondary && fillMode == "outlineFill" {
            drawFilledRoundedRect(ctx: &ctx, x0: x0, y0: y0, x1: x1, y1: y1, r: r, color: ctx.bgColor)
            startPoint = nil
            return
        }

        // Fill
        if fillMode == "fill" || fillMode == "outlineFill" {
            drawFilledRoundedRect(ctx: &ctx, x0: x0, y0: y0, x1: x1, y1: y1, r: r, color: ctx.bgColor)
        }

        // Outline
        if fillMode == "outline" || fillMode == "outlineFill" {
            drawOutlineRoundedRect(ctx: &ctx, x0: x0, y0: y0, x1: x1, y1: y1, r: r, lw: lw, halfWidth: halfWidth, color: ctx.fgColor)
        }

        startPoint = nil
    }

    // MARK: - Fill

    private func drawFilledRoundedRect(ctx: inout ToolContext, x0: Int, y0: Int, x1: Int, y1: Int, r: Int, color: (UInt8, UInt8, UInt8)) {
        guard r > 0, x0 + r <= x1 - r else {
            // Too small for rounding; fill entire rect
            for fy in y0...y1 {
                for fx in x0...x1 {
                    ctx.bitmap.setPixel(x: fx, y: fy, color: color)
                }
            }
            return
        }

        // Central rect (straight middle section)
        let midY0 = y0 + r
        let midY1 = y1 - r
        if midY0 <= midY1 {
            for fy in midY0...midY1 {
                for fx in x0...x1 {
                    ctx.bitmap.setPixel(x: fx, y: fy, color: color)
                }
            }
        }

        // Top and bottom arc sections
        drawHorizontalSpanRows(ctx: &ctx, x0: x0, y0: y0, x1: x1, y1: y1, r: r, color: color)
    }

    private func drawHorizontalSpanRows(ctx: inout ToolContext, x0: Int, y0: Int, x1: Int, y1: Int, r: Int, color: (UInt8, UInt8, UInt8)) {
        // For each y in the top arc [y0, y0+r] and bottom arc [y1-r, y1],
        // compute the x-span of the rounded rectangle.
        // Use the midpoint circle to determine the chord at each row.

        guard r > 0 else { return }

        // Top arc: quarter circle centered at (x0+r, y0+r) for upper-left,
        // and at (x1-r, y0+r) for upper-right.
        // For each y from y0 to y0+r:
        //   For left side: find the rightmost x of the quarter circle at center (x0+r, y0+r)
        //   For right side: find the leftmost x of the quarter circle at center (x1-r, y0+r)
        //   Span = [leftX, rightX] clipped

        // Bottom arc similar with centers at (x0+r, y1-r) and (x1-r, y1-r)

        // We'll use the midpoint circle to compute the boundary.
        // For a circle of radius r centered at (cx, cy), the arc in the
        // top-left quadrant (for upper-left corner) has points where
        // x <= cx and y <= cy.

        let midY0 = y0 + r
        let midY1 = y1 - r

        // Top section: y in [y0, midY0]
        for y in y0...midY0 {
            var spanX0 = x0
            var spanX1 = x1

            // Left corner: circle center (x0+r, y0+r), quarter circle where x <= cx, y <= cy
            // For this y, find x from the circle equation: (x - cx)^2 + (y - cy)^2 <= r^2
            let leftCx = x0 + r
            let topCy = y0 + r
            let dy_top = topCy - y // >= 0
            let dy2_top = dy_top * dy_top
            let r2 = r * r
            if dy2_top <= r2 {
                let dx_top = Int(Darwin.sqrt(Double(r2 - dy2_top)))
                spanX0 = max(spanX0, leftCx - dx_top)
            }

            // Right corner: circle center (x1-r, y0+r)
            let rightCx = x1 - r
            if dy2_top <= r2 {
                let dx_top = Int(Darwin.sqrt(Double(r2 - dy2_top)))
                spanX1 = min(spanX1, rightCx + dx_top)
            }

            if spanX0 <= spanX1 {
                for x in spanX0...spanX1 {
                    ctx.bitmap.setPixel(x: x, y: y, color: color)
                }
            }
        }

        // Bottom section: y in [midY1, y1]
        if midY1 <= y1 {
            for y in midY1...y1 {
                var spanX0 = x0
                var spanX1 = x1

                let leftCx = x0 + r
                let botCy = y1 - r
                let dy_bot = y - botCy // >= 0
                let dy2_bot = dy_bot * dy_bot
                let r2 = r * r

                if dy2_bot <= r2 {
                    let dx_bot = Int(Darwin.sqrt(Double(r2 - dy2_bot)))
                    spanX0 = max(spanX0, leftCx - dx_bot)
                }

                let rightCx = x1 - r
                if dy2_bot <= r2 {
                    let dx_bot = Int(Darwin.sqrt(Double(r2 - dy2_bot)))
                    spanX1 = min(spanX1, rightCx + dx_bot)
                }

                if spanX0 <= spanX1 {
                    for x in spanX0...spanX1 {
                        ctx.bitmap.setPixel(x: x, y: y, color: color)
                    }
                }
            }
        }
    }

    // MARK: - Outline

    private func drawOutlineRoundedRect(ctx: inout ToolContext, x0: Int, y0: Int, x1: Int, y1: Int, r: Int, lw: Int, halfWidth: Int, color: (UInt8, UInt8, UInt8)) {
        if lw <= 0 { return }
        if lw == 1 {
            drawRoundedRectOutline(ctx: &ctx, x0: x0, y0: y0, x1: x1, y1: y1, r: r, color: color)
        } else {
            for i in 0..<lw {
                let offset = i - halfWidth
                var insetR = r + offset
                if insetR < 0 { insetR = 0 }
                drawRoundedRectOutline(ctx: &ctx, x0: x0 + i, y0: y0 + i, x1: x1 - i, y1: y1 - i, r: insetR, color: color)
            }
        }
    }

    private func drawRoundedRectOutline(ctx: inout ToolContext, x0: Int, y0: Int, x1: Int, y1: Int, r: Int, color: (UInt8, UInt8, UInt8)) {
        guard x0 <= x1 && y0 <= y1 else { return }

        let effectiveR = min(r, min((x1 - x0) / 2, (y1 - y0) / 2))
        if effectiveR <= 0 {
            // Fallback: draw a plain rectangle outline
            for i in x0...x1 {
                ctx.bitmap.setPixel(x: i, y: y0, color: color)
                ctx.bitmap.setPixel(x: i, y: y1, color: color)
            }
            for i in y0...y1 {
                ctx.bitmap.setPixel(x: x0, y: i, color: color)
                ctx.bitmap.setPixel(x: x1, y: i, color: color)
            }
            return
        }

        // Top edge: (x0+r, y0) to (x1-r, y0)
        for x in (x0 + effectiveR)...(x1 - effectiveR) {
            ctx.bitmap.setPixel(x: x, y: y0, color: color)
        }

        // Bottom edge: (x0+r, y1) to (x1-r, y1)
        for x in (x0 + effectiveR)...(x1 - effectiveR) {
            ctx.bitmap.setPixel(x: x, y: y1, color: color)
        }

        // Left edge: (x0, y0+r) to (x0, y1-r)
        for y in (y0 + effectiveR)...(y1 - effectiveR) {
            ctx.bitmap.setPixel(x: x0, y: y, color: color)
        }

        // Right edge: (x1, y0+r) to (x1, y1-r)
        for y in (y0 + effectiveR)...(y1 - effectiveR) {
            ctx.bitmap.setPixel(x: x1, y: y, color: color)
        }

        // Four quarter-circle arcs using midpoint circle algorithm
        // Top-left: center (x0+r, y0+r), arc from left to top
        drawQuarterCircle(ctx: &ctx, cx: x0 + effectiveR, cy: y0 + effectiveR, r: effectiveR, quadrant: .topLeft, color: color)
        // Top-right: center (x1-r, y0+r), arc from top to right
        drawQuarterCircle(ctx: &ctx, cx: x1 - effectiveR, cy: y0 + effectiveR, r: effectiveR, quadrant: .topRight, color: color)
        // Bottom-left: center (x0+r, y1-r), arc from bottom to left
        drawQuarterCircle(ctx: &ctx, cx: x0 + effectiveR, cy: y1 - effectiveR, r: effectiveR, quadrant: .bottomLeft, color: color)
        // Bottom-right: center (x1-r, y1-r), arc from right to bottom
        drawQuarterCircle(ctx: &ctx, cx: x1 - effectiveR, cy: y1 - effectiveR, r: effectiveR, quadrant: .bottomRight, color: color)

        // Ensure bounding box corner pixels are drawn
        ctx.bitmap.setPixel(x: x0, y: y0, color: color)
        ctx.bitmap.setPixel(x: x1, y: y0, color: color)
        ctx.bitmap.setPixel(x: x0, y: y1, color: color)
        ctx.bitmap.setPixel(x: x1, y: y1, color: color)
    }

    private enum Quadrant { case topLeft, topRight, bottomLeft, bottomRight }

    private func drawQuarterCircle(ctx: inout ToolContext, cx: Int, cy: Int, r: Int, quadrant: Quadrant, color: (UInt8, UInt8, UInt8)) {
        guard r > 0 else { return }

        // Midpoint circle algorithm, plotting only the desired quadrant
        var x: Int64 = 0
        var y: Int64 = Int64(r)
        var d: Int64 = 1 - Int64(r)

        while x <= y {
            switch quadrant {
            case .topLeft:
                // x <= cx, y <= cy -> plot at (cx - x, cy - y) and (cx - y, cy - x)
                ctx.bitmap.setPixel(x: cx - Int(x), y: cy - Int(y), color: color)
                ctx.bitmap.setPixel(x: cx - Int(y), y: cy - Int(x), color: color)
            case .topRight:
                // x >= cx, y <= cy -> plot at (cx + x, cy - y) and (cx + y, cy - x)
                ctx.bitmap.setPixel(x: cx + Int(x), y: cy - Int(y), color: color)
                ctx.bitmap.setPixel(x: cx + Int(y), y: cy - Int(x), color: color)
            case .bottomLeft:
                // x <= cx, y >= cy -> plot at (cx - x, cy + y) and (cx - y, cy + x)
                ctx.bitmap.setPixel(x: cx - Int(x), y: cy + Int(y), color: color)
                ctx.bitmap.setPixel(x: cx - Int(y), y: cy + Int(x), color: color)
            case .bottomRight:
                // x >= cx, y >= cy -> plot at (cx + x, cy + y) and (cx + y, cy + x)
                ctx.bitmap.setPixel(x: cx + Int(x), y: cy + Int(y), color: color)
                ctx.bitmap.setPixel(x: cx + Int(y), y: cy + Int(x), color: color)
            }

            if d < 0 {
                d += 2 * x + 3
            } else {
                d += 2 * (x - y) + 5
                y -= 1
            }
            x += 1
        }
    }
}
