import Foundation

struct Bitmap {
    var width: Int
    var height: Int
    var pixels: [UInt8] // RGB, row-major, no alpha

    init(width: Int, height: Int, color: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: width * height * 3)
        fill(color: color)
    }

    private func index(x: Int, y: Int) -> Int {
        return (y * width + x) * 3
    }

    subscript(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        get {
            let i = index(x: x, y: y)
            return (pixels[i], pixels[i + 1], pixels[i + 2])
        }
        set {
            let i = index(x: x, y: y)
            pixels[i] = newValue.r
            pixels[i + 1] = newValue.g
            pixels[i + 2] = newValue.b
        }
    }

    mutating func fill(color: (r: UInt8, g: UInt8, b: UInt8)) {
        for y in 0..<height {
            for x in 0..<width {
                self[x, y] = color
            }
        }
    }

    mutating func setPixel(x: Int, y: Int, color: (r: UInt8, g: UInt8, b: UInt8)) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        self[x, y] = color
    }

    func pixelAt(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
        return self[x, y]
    }

    mutating func drawLine(x0: Int, y0: Int, x1: Int, y1: Int, color: (UInt8, UInt8, UInt8)) {
        var x0 = x0, y0 = y0
        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        while true {
            setPixel(x: x0, y: y0, color: color)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x0 += sx
            }
            if e2 < dx {
                err += dx
                y0 += sy
            }
        }
    }

    mutating func drawDottedLine(points: [(Int, Int)], color: (UInt8, UInt8, UInt8)) {
        guard points.count >= 2 else {
            if let p = points.first {
                setPixel(x: p.0, y: p.1, color: color)
            }
            return
        }
        for p in points {
            setPixel(x: p.0, y: p.1, color: color)
        }
        for i in 0..<(points.count - 1) {
            drawLine(x0: points[i].0, y0: points[i].1,
                     x1: points[i + 1].0, y1: points[i + 1].1,
                     color: color)
        }
    }

    mutating func floodFill(x: Int, y: Int, targetColor: (UInt8, UInt8, UInt8), fillColor: (UInt8, UInt8, UInt8)) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        guard targetColor.0 != fillColor.0 || targetColor.1 != fillColor.1 || targetColor.2 != fillColor.2 else { return }
        guard self[x, y].r == targetColor.0 && self[x, y].g == targetColor.1 && self[x, y].b == targetColor.2 else { return }

        var stack: [(Int, Int)] = [(x, y)]
        var visited = [Bool](repeating: false, count: width * height)

        while !stack.isEmpty {
            let (cx, cy) = stack.removeLast()
            guard cx >= 0 && cx < width && cy >= 0 && cy < height else { continue }
            let idx = cy * width + cx
            if visited[idx] { continue }
            visited[idx] = true

            let pixel = self[cx, cy]
            guard pixel.r == targetColor.0 && pixel.g == targetColor.1 && pixel.b == targetColor.2 else { continue }

            self[cx, cy] = fillColor

            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }
    }
}
