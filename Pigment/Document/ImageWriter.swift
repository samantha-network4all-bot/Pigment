import AppKit

enum ImageWriter {
    enum Format: String { case png, jpeg, bmp }
    enum Error: Swift.Error { case unsupportedFormat(String) }

    static func write(bitmap: Bitmap, format: String, path: String) throws {
        guard let bmpFmt = Format(rawValue: format) else {
            throw Error.unsupportedFormat(format)
        }
        let w = bitmap.width
        let h = bitmap.height
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: w,
                                    pixelsHigh: h,
                                    bitsPerSample: 8,
                                    samplesPerPixel: 3,
                                    hasAlpha: false,
                                    isPlanar: false,
                                    colorSpaceName: .deviceRGB,
                                    bytesPerRow: w * 3,
                                    bitsPerPixel: 24)!
        for y in 0..<h {
            for x in 0..<w {
                let p = bitmap[x, y]
                var pixelVals: [Int] = [Int(p.r), Int(p.g), Int(p.b)]
                rep.setPixel(&pixelVals, atX: x, y: y)
            }
        }
        let fileType: NSBitmapImageRep.FileType
        switch bmpFmt {
        case .png:  fileType = .png
        case .jpeg: fileType = .jpeg
        case .bmp:  fileType = .bmp
        }
        let props: [NSBitmapImageRep.PropertyKey: Any] = bmpFmt == .jpeg ? [.compressionFactor: 0.9] : [:]
        guard let data = rep.representation(using: fileType, properties: props) else {
            throw NSError(domain: "ImageWriter", code: 2, userInfo: [NSLocalizedDescriptionKey: "representation failed"])
        }
        (data as NSData).write(toFile: path, atomically: true)
    }
}
