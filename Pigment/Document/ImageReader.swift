import AppKit

enum ImageReader {
    static func read(from path: String) -> Bitmap? {
        guard let data = NSData(contentsOfFile: path),
              let rep = NSBitmapImageRep(data: data as Data) else { return nil }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        var bmp = Bitmap(width: w, height: h)
        guard let bytes = rep.bitmapData else { return bmp }
        for y in 0..<h {
            for x in 0..<w {
                let srcIdx = y * rep.bytesPerRow + x * 4
                let r = bytes[srcIdx]
                let g = bytes[srcIdx + 1]
                let b = bytes[srcIdx + 2]
                bmp.setPixel(x: x, y: y, color: (r, g, b))
            }
        }
        return bmp
    }
}
