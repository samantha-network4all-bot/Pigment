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
}
