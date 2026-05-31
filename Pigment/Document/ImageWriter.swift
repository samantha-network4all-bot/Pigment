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
        // Build raw RGB data matching the bitmap exactly
        var rgbData = [UInt8](repeating: 0, count: w * h * 3)
        for y in 0..<h {
            for x in 0..<w {
                let p = bitmap[x, y]
                let idx = (y * w + x) * 3
                rgbData[idx]     = p.r
                rgbData[idx + 1] = p.g
                rgbData[idx + 2] = p.b
            }
        }
        let data = Data(rgbData)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: w,
                height: h,
                bitsPerComponent: 8,
                bitsPerPixel: 24,
                bytesPerRow: w * 3,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw NSError(domain: "ImageWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "CGImage creation failed"])
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let fileType: NSBitmapImageRep.FileType
        switch bmpFmt {
        case .png:  fileType = .png
        case .jpeg: fileType = .jpeg
        case .bmp:  fileType = .bmp
        }
        let props: [NSBitmapImageRep.PropertyKey: Any] = bmpFmt == .jpeg ? [.compressionFactor: 0.9] : [:]
        guard let outData = rep.representation(using: fileType, properties: props) else {
            throw NSError(domain: "ImageWriter", code: 2, userInfo: [NSLocalizedDescriptionKey: "representation failed"])
        }
        (outData as NSData).write(toFile: path, atomically: true)
    }
}
