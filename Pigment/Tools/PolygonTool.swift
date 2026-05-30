import AppKit

final class PolygonTool: Tool {
    var id: String { "polygon" }
    var cursor: NSCursor { .crosshair }

    private var vertices: [(Int, Int)] = []

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        vertices.append((Int(point.x.rounded()), Int(point.y.rounded())))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        vertices.append((x, y))
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        vertices.append((x, y))

        let polyVerts = extractStrokeVertices(vertices)
        let lw = ctx.options.lineWidth

        if polyVerts.count >= 3 {
            for i in 0..<(polyVerts.count - 1) {
                drawEdge(&ctx, from: polyVerts[i], to: polyVerts[i + 1], lw: lw)
            }
            // Close the polygon: draw from last vertex back to first
            drawEdge(&ctx, from: polyVerts[polyVerts.count - 1], to: polyVerts[0], lw: lw)
        } else if polyVerts.count == 2 {
            drawEdge(&ctx, from: polyVerts[0], to: polyVerts[1], lw: lw)
        }

        vertices.removeAll()
    }

    // Extract the original polygon vertices from the accumulated point list.
    // The CanvasController interpolates between consecutive original stroke
    // points via Bresenham interpolation.  Original vertices appear at the
    // joints where the overall path direction changes.  We detect those
    // junctions by sweeping a window across the accumulated sequence and
    // computing the angle between the incoming and outgoing displacement
    // vectors; a large enough angle marks a corner candidate.  Nearby
    // candidates are clustered and a single vertex is kept per cluster.
    private func extractStrokeVertices(_ pts: [(Int, Int)]) -> [(Int, Int)] {
        // De-duplicate consecutive identical points (the CanvasController may
        // send the stroke endpoint both as the last interpolated drag and as
        // the pointerUp point).
        var cleanPts: [(Int, Int)] = []
        cleanPts.reserveCapacity(pts.count)
        for p in pts {
            if let last = cleanPts.last, last.0 == p.0 && last.1 == p.1 { continue }
            cleanPts.append(p)
        }

        guard cleanPts.count >= 2 else { return cleanPts }
        if cleanPts.count <= 2 { return [cleanPts[0], cleanPts[cleanPts.count - 1]] }

        let W = 5  // half-window for direction estimation

        var candidates: [(Int, Int)] = []

        for i in W..<(cleanPts.count - W) {
            let v1x = cleanPts[i].0 - cleanPts[i - W].0
            let v1y = cleanPts[i].1 - cleanPts[i - W].1
            let v2x = cleanPts[i + W].0 - cleanPts[i].0
            let v2y = cleanPts[i + W].1 - cleanPts[i].1

            let cross = v1x * v2y - v1y * v2x
            let lenSq1 = v1x * v1x + v1y * v1y
            let lenSq2 = v2x * v2x + v2y * v2y

            if lenSq1 < W || lenSq2 < W { continue }

            let crossSq = cross * cross
            if crossSq * 100 > lenSq1 * lenSq2 * 12 {
                candidates.append(cleanPts[i])
            }
        }

        var result: [(Int, Int)] = [cleanPts[0]]

        // Cluster nearby candidates and keep the centroid of each cluster.
        var cs = 0
        while cs < candidates.count {
            var ce = cs
            while ce + 1 < candidates.count &&
                  abs(candidates[ce + 1].0 - candidates[cs].0) < W * 2 &&
                  abs(candidates[ce + 1].1 - candidates[cs].1) < W * 2 {
                ce += 1
            }
            let mid = (cs + ce) / 2
            let v = candidates[mid]
            let last = result[result.count - 1]
            if v.0 != last.0 || v.1 != last.1 {
                result.append(v)
            }
            cs = ce + 1
        }

        // Always append the actual final stroke point.
        let lastPt = cleanPts[cleanPts.count - 1]
        let lastResult = result[result.count - 1]
        if lastPt.0 != lastResult.0 || lastPt.1 != lastResult.1 {
            result.append(lastPt)
        }

        return result
    }

    // Draw a single edge segment with the given lineWidth.
    // For lineWidth == 1 uses Bresenham directly.
    // For lineWidth > 1 draws `lineWidth` parallel offset lines
    // perpendicular to the segment (same approach as LineTool).
    private func drawEdge(_ ctx: inout ToolContext, from: (Int, Int), to: (Int, Int), lw: Int) {
        let color = ctx.fgColor

        if lw <= 1 {
            ctx.bitmap.drawLine(x0: from.0, y0: from.1, x1: to.0, y1: to.1, color: color)
            return
        }

        let dx = to.0 - from.0
        let dy = to.1 - from.1
        let len = Double(dx * dx + dy * dy).squareRoot()

        if len < 1 {
            // Degenerate: draw a thick point centred on `from`.
            let half = lw / 2
            for ody in -half..<(lw - half) {
                for odx in -half..<(lw - half) {
                    ctx.bitmap.setPixel(x: from.0 + odx, y: from.1 + ody, color: color)
                }
            }
            return
        }

        // Perpendicular unit vector.
        let nx = -Double(dy) / len
        let ny = Double(dx) / len
        let half = Double(lw - 1) / 2.0

        for i in 0..<lw {
            let offset = Double(i) - half
            let ox = Int(floor(nx * offset))
            let oy = Int(floor(ny * offset))
            ctx.bitmap.drawLine(x0: from.0 + ox, y0: from.1 + oy,
                               x1: to.0 + ox, y1: to.1 + oy,
                               color: color)
        }
    }
}
