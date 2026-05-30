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
        // Skip duplicate points
        if last.0 == px && last.1 == py { return }
        vertices.append((px, py))
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        guard !vertices.isEmpty else { return }
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        let last = vertices[vertices.count - 1]
        if last.0 != px || last.1 != py {
            vertices.append((px, py))
        }

        // Extract corner vertices (where direction changes)
        let corners = extractCorners(vertices)

        // Draw polygon outline and fill
        if corners.count >= 2 {
            // Draw and fill the polygon
            drawPolygon(ctx: &ctx, corners: corners)
        }

        vertices.removeAll()
    }

    /// Draw polygon outline and fill based on fillMode
    private func drawPolygon(ctx: inout ToolContext, corners: [(Int, Int)]) {
        let fillMode = ctx.options.fillMode
        let color = ctx.fgColor
        let bg = ctx.bgColor

        // Fill interior if needed
        if fillMode == "fill" || fillMode == "outlineFill" {
            fillPolygon(ctx: &ctx, corners: corners, color: bg)
        }

        // Draw outline
        if fillMode == "outline" || fillMode == "outlineFill" {
            if corners.count >= 2 {
                for i in 0..<(corners.count - 1) {
                    drawEdge(ctx: &ctx, from: corners[i], to: corners[i + 1])
                }
                // Close polygon
                let first = corners[0]
                let lastCorner = corners[corners.count - 1]
                if first.0 != lastCorner.0 || first.1 != lastCorner.1 {
                    drawEdge(ctx: &ctx, from: lastCorner, to: first)
                }
            }
        } else if fillMode == "fill" {
            // fill only mode: no outline
        }
    }

    /// Scanline fill of polygon interior
    private func fillPolygon(ctx: inout ToolContext, corners: [(Int, Int)], color: (UInt8, UInt8, UInt8)) {
        guard corners.count >= 3 else { return }

        // Find bounding box
        var minY = corners[0].1
        var maxY = corners[0].1
        for c in corners {
            if c.1 < minY { minY = c.1 }
            if c.1 > maxY { maxY = c.1 }
        }

        let w = ctx.bitmap.width
        let h = ctx.bitmap.height

        // Clip to bitmap bounds
        if minY < 0 { minY = 0 }
        if maxY >= h { maxY = h - 1 }

        // For each scanline, find intersections with polygon edges
        for y in minY...maxY {
            var intersections: [Int] = []

            for i in 0..<corners.count {
                let j = (i + 1) % corners.count
                let (x1, y1) = corners[i]
                let (x2, y2) = corners[j]

                // Check if scanline crosses this edge
                if (y1 <= y && y < y2) || (y2 <= y && y < y1) {
                    // Calculate x intersection
                    let dy = y2 - y1
                    if dy != 0 {
                        let t = Double(y - y1) / Double(dy)
                        let x = Double(x1) + t * Double(x2 - x1)
                        intersections.append(Int(x.rounded()))
                    }
                }
            }

            intersections.sort()

            // Fill between pairs of intersections
            var i = 0
            while i + 1 < intersections.count {
                var xStart = intersections[i]
                let xEnd = intersections[i + 1]

                // Clip to bitmap
                if xStart < 0 { xStart = 0 }
                if xEnd >= w { break }

                for x in xStart...xEnd {
                    ctx.bitmap.setPixel(x: x, y: y, color: color)
                }
                i += 2
            }
        }
    }

    /// Extract corner vertices from a path of points.
    /// A corner is where the direction changes significantly.
    private func extractCorners(_ points: [(Int, Int)]) -> [(Int, Int)] {
        guard points.count >= 2 else { return points }

        var corners: [(Int, Int)] = [points[0]]

        var prevDx = points[1].0 - points[0].0
        var prevDy = points[1].1 - points[0].1

        for i in 2..<points.count {
            let dx = points[i].0 - points[i - 1].0
            let dy = points[i].1 - points[i - 1].1

            // Normalize direction to handle different step sizes
            let prevDir = normalizeDir(dx: prevDx, dy: prevDy)
            let currDir = normalizeDir(dx: dx, dy: dy)

            // If direction changed, the previous point was a corner
            if prevDir.0 != currDir.0 || prevDir.1 != currDir.1 {
                corners.append(points[i - 1])
                prevDx = dx
                prevDy = dy
            }
        }

        // Always include the last point
        corners.append(points[points.count - 1])

        return corners
    }

    /// Normalize a direction vector to its sign components (-1, 0, or 1)
    private func normalizeDir(dx: Int, dy: Int) -> (Int, Int) {
        let nx = dx == 0 ? 0 : (dx > 0 ? 1 : -1)
        let ny = dy == 0 ? 0 : (dy > 0 ? 1 : -1)
        return (nx, ny)
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
            let half = Double(lw - 1) / 2.0
            for i in 0..<lw {
                let offset = Double(i) - half
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
