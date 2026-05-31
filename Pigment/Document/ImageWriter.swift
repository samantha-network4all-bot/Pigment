import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageWriter {
    enum Format: String { case png, jpeg, bmp }
    enum Error: Swift.Error { case unsupportedFormat(String) }

    static func write(bitmap: Bitmap, format: String, path: String) throws {
        guard let bmpFmt = Format(rawValue: format) else {
            throw Error.unsupportedFormat(format)
        }
        let w = bitmap.width
        let h = bitmap.height

        // Build RGBA pixel data - initialized to white (255,255,255)
        var pixelData = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let p = bitmap[x, y]
                let idx = (y * w + x) * 4
                pixelData[idx]     = p.r
                pixelData[idx + 1] = p.g
                pixelData[idx + 2] = p.b
                // alpha stays 255
            }
        }


        // Create CGImage with explicit sRGB, no color management surprises
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let provider = CGDataProvider(data: Data(pixelData) as CFData),
              let cgImage = CGImage(width: w, height: h,
                                    bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: w * 4,
                                    space: cs,
                                    bitmapInfo: bitmapInfo,
                                    provider: provider,
                                    decode: nil,
                                    shouldInterpolate: false,
                                    intent: .defaultIntent) else {
            throw NSError(domain: "ImageWriter", code: 4, userInfo: [NSLocalizedDescriptionKey: "CGImage creation failed"])
        }

        // Write via CGImageDestination
        let url = URL(fileURLWithPath: path) as CFURL
        let destType: CFString
        var props: [CFString: Any] = [:]
        switch bmpFmt {
        case .png:
            destType = UTType.png.identifier as CFString
        case .jpeg:
            destType = UTType.jpeg.identifier as CFString
            props[kCGImageDestinationLossyCompressionQuality] = 0.9
        case .bmp:
            destType = UTType.bmp.identifier as CFString
        }
        guard let dest = CGImageDestinationCreateWithURL(url, destType, 1, nil) else {
            throw NSError(domain: "ImageWriter", code: 5, userInfo: [NSLocalizedDescriptionKey: "CGImageDestination creation failed"])
        }
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "ImageWriter", code: 6, userInfo: [NSLocalizedDescriptionKey: "CGImageDestination finalize failed"])
        }
    }
}
