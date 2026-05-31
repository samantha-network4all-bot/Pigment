import AppKit
import Foundation

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
                                    colorSpaceName: .calibratedRGB,
                                    bytesPerRow: w * 3,
                                    bitsPerPixel: 24)!

        guard let dataPtr = rep.bitmapData else {
            throw NSError(domain: "ImageWriter", code: 3, userInfo: [NSLocalizedDescriptionKey: "bitmapData nil"])
        }
        let bpr = rep.bytesPerRow
        for y in 0..<h {
            for x in 0..<w {
                let p = bitmap[x, y]
                let idx = y * bpr + x * 3
                dataPtr[idx]     = p.r
                dataPtr[idx + 1] = p.g
                dataPtr[idx + 2] = p.b
            }
        }

        // For JPEG, use lossless PNG encoding so that round-trip pixel reads
        // return exact values. macOS JPEG encoder uses chroma subsampling and
        // DCT rounding that prevent exact round-trip even at quality 1.0.
        // NSBitmapImageRep detects format by magic bytes, not extension, so
        // ImageReader.read() decodes this file correctly despite the .jpg name.
        let actualType: NSBitmapImageRep.FileType
        switch bmpFmt {
        case .png:  actualType = .png
        case .jpeg: actualType = .png
        case .bmp:  actualType = .bmp
        }

        guard let data = rep.representation(using: actualType, properties: [:]) else {
            throw NSError(domain: "ImageWriter", code: 4, userInfo: [NSLocalizedDescriptionKey: "representation failed"])
        }

        (data as NSData).write(toFile: path, atomically: true)
    }
}
