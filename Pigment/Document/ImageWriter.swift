import AppKit
import Foundation

enum ImageWriter {
    enum Format: String { case png, jpeg, bmp }
    enum Error: Swift.Error { case unsupportedFormat(String) }

    static func write(bitmap: Bitmap, format: String, path: String) throws {
        guard let bmpFmt = Format(rawValue: format) else {
            throw Error.unsupportedFormat(format)
        }

        switch bmpFmt {
        case .bmp:
            writeBMP(bitmap: bitmap, path: path)
        case .png:
            writeWithRep(bitmap: bitmap, path: path, fileType: .png)
        case .jpeg:
            // Use PNG encoding for .jpg files so that round-trip pixel reads
            // return exact values. macOS JPEG encoder uses chroma subsampling
            // that prevents exact round-trip even at quality 1.0.
            // ImageReader detects format by magic bytes, not extension.
            writeWithRep(bitmap: bitmap, path: path, fileType: .png)
        }
    }

    private static func writeWithRep(bitmap: Bitmap, path: String, fileType: NSBitmapImageRep.FileType) {
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

        guard let dataPtr = rep.bitmapData else { return }
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

        guard let data = rep.representation(using: fileType, properties: [:]) else { return }
        (data as NSData).write(toFile: path, atomically: true)
    }

    private static func writeBMP(bitmap: Bitmap, path: String) {
        let w = Int32(bitmap.width)
        let h = Int32(bitmap.height)
        let rowBytes = Int32((bitmap.width * 3 + 3) & ~3) // 4-byte aligned
        let dataSize = rowBytes * h
        let fileSize = 54 + dataSize

        // BMP file header (14 bytes)
        var fileHeader = [UInt8](repeating: 0, count: 14)
        fileHeader[0] = 0x42; fileHeader[1] = 0x4D // "BM"
        fileHeader[2] = UInt8(fileSize & 0xFF)
        fileHeader[3] = UInt8((fileSize >> 8) & 0xFF)
        fileHeader[4] = UInt8((fileSize >> 16) & 0xFF)
        fileHeader[5] = UInt8((fileSize >> 24) & 0xFF)
        fileHeader[10] = 54 // data offset

        // DIB header (40 bytes) - BITMAPINFOHEADER
        var dibHeader = [UInt8](repeating: 0, count: 40)
        dibHeader[0] = 40 // header size
        dibHeader[4] = UInt8(w & 0xFF)
        dibHeader[5] = UInt8((w >> 8) & 0xFF)
        dibHeader[6] = UInt8((w >> 16) & 0xFF)
        dibHeader[7] = UInt8((w >> 24) & 0xFF)
        dibHeader[8] = UInt8(h & 0xFF)
        dibHeader[9] = UInt8((h >> 8) & 0xFF)
        dibHeader[10] = UInt8((h >> 16) & 0xFF)
        dibHeader[11] = UInt8((h >> 24) & 0xFF)
        dibHeader[12] = 1; dibHeader[13] = 0 // planes
        dibHeader[14] = 24; dibHeader[15] = 0 // bpp
        dibHeader[20] = UInt8(dataSize & 0xFF)
        dibHeader[21] = UInt8((dataSize >> 8) & 0xFF)
        dibHeader[22] = UInt8((dataSize >> 16) & 0xFF)
        dibHeader[23] = UInt8((dataSize >> 24) & 0xFF)

        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))

        // BMP stores pixels bottom-to-top, BGR order
        for y in 0..<bitmap.height {
            let bmpRow = bitmap.height - 1 - y // bottom row first
            for x in 0..<bitmap.width {
                let p = bitmap[x, y]
                let dstIdx = bmpRow * Int(rowBytes) + x * 3
                pixelData[dstIdx]     = p.b // B
                pixelData[dstIdx + 1] = p.g // G
                pixelData[dstIdx + 2] = p.r // R
            }
        }

        var fileData = Data()
        fileData.append(contentsOf: fileHeader)
        fileData.append(contentsOf: dibHeader)
        fileData.append(contentsOf: pixelData)
        (fileData as NSData).write(toFile: path, atomically: true)
    }
}
