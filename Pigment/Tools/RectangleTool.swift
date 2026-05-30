import AppKit

final class RectangleTool: Tool {
    var id: String { "rectangle" }
    var cursor: NSCursor { .crosshair }

    private var startPoint: (Int, Int)?

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        startPoint = (Int(point.x.rounded()), Int(point.y.rounded()))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        // no-op: rectangle commits on pointerUp
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard let (sx, sy) = startPoint else { return }
        let x0 = min(sx, Int(point.x.rounded()))
        let y0 = min(sy, Int(point.y.rounded()))
        let x1 = max(sx, Int(point.x.rounded()))
        let y1 = max(sy, Int(point.y.rounded()))

        let fillMode = ctx.options.fillMode
        let lw = ctx.options.lineWidth
        let halfWidth = lw / 2
        let isSecondary = ctx.button == .secondary

        // Right-click with outlineFill: fill interior with bgColor, no border.
        // CanvasController maps ctx.fgColor = bgColor for secondary click,
        // so both fgColor and bgColor are the same (bgColor). We skip the
        // border draw to keep corners at the original canvas color.
        if isSecondary && fillMode == "outlineFill" {
            let fillX0 = x0 + lw
            let fillY0 = y0 + lw
            let fillX1 = x1 - lw
            let fillY1 = y1 - lw
            if fillX0 <= fillX1 && fillY0 <= fillY1 {
                for fy in fillY0...fillY1 {
                    for fx in fillX0...fillX1 {
                        ctx.bitmap.setPixel(x: fx, y: fy, color: ctx.bgColor)
                    }
                }
            } else {
                for fy in y0...y1 {
                    for fx in x0...x1 {
                        ctx.bitmap.setPixel(x: fx, y: fy, color: ctx.bgColor)
                    }
                }
            }
            startPoint = nil
            return
        }

        // Draw fill (interior) — uses bgColor
        if fillMode == "fill" || fillMode == "outlineFill" {
            let fillX0 = x0 + halfWidth
            let fillY0 = y0 + halfWidth
            let fillX1 = x1 - halfWidth
            let fillY1 = y1 - halfWidth
            if fillX0 <= fillX1 && fillY0 <= fillY1 {
                for fy in fillY0...fillY1 {
                    for fx in fillX0...fillX1 {
                        ctx.bitmap.setPixel(x: fx, y: fy, color: ctx.bgColor)
                    }
                }
            } else {
                // Rect too small for interior; fill the whole area
                for fy in y0...y1 {
                    for fx in x0...x1 {
                        ctx.bitmap.setPixel(x: fx, y: fy, color: ctx.bgColor)
                    }
                }
            }
        }

        // Draw border (4 edges with thickness = lineWidth) — uses fgColor
        if fillMode == "outline" || fillMode == "outlineFill" {
            for i in 0..<lw {
                let offset = i - halfWidth
                // Top edge
                ctx.bitmap.drawLine(x0: x0, y0: y0 + offset, x1: x1, y1: y0 + offset, color: ctx.fgColor)
                // Bottom edge
                ctx.bitmap.drawLine(x0: x0, y0: y1 + offset, x1: x1, y1: y1 + offset, color: ctx.fgColor)
                // Left edge
                ctx.bitmap.drawLine(x0: x0 + offset, y0: y0, x1: x0 + offset, y1: y1, color: ctx.fgColor)
                // Right edge
                ctx.bitmap.drawLine(x0: x1 + offset, y0: y0, x1: x1 + offset, y1: y1, color: ctx.fgColor)
            }
        }

        startPoint = nil
    }
}
