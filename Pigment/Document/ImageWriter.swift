import AppKit

enum ImageWriter {
    enum Format: String { case png, jpeg, bmp }

    static func write(bitmap: Bitmap, format: String, path: String) -> Bool {
        guard let bmpFmt = Format(rawValue: format) else { return false }
        let w = bitmap.width
        let h = bitmap.height
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: w * 3,
            bitsPerPixel: 24
        ) else { return false }

        guard let dst = rep.bitmapData else { return false }
        for y in 0..<h {
            for x in 0..<w {
                let p = bitmap[x, y]
                let idx = y * rep.bytesPerRow + x * 3
                dst[idx]     = p.r
                dst[idx + 1] = p.g
                dst[idx + 2] = p.b
            }
        }

        let fileType: NSBitmapImageRep.FileType
        switch bmpFmt {
        case .png:  fileType = .png
        case .jpeg: fileType = .jpeg
        case .bmp:  fileType = .bmp
        }
        let props: [NSBitmapImageRep.PropertyKey: Any] = bmpFmt == .jpeg ? [.compressionFactor: 0.9] : [:]
        guard let data = rep.representation(using: fileType, properties: props) else { return false }
        return (data as NSData).write(toFile: path, atomically: true)
    }
}
