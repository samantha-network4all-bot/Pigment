import Foundation

final class ColorState {
    private var fgHex: String = "#000000"
    private var bgHex: String = "#FFFFFF"

    var fgColor: (UInt8, UInt8, UInt8) {
        hexToRGB(fgHex)
    }

    var bgColor: (UInt8, UInt8, UInt8) {
        hexToRGB(bgHex)
    }

    private func hexToRGB(_ hex: String) -> (UInt8, UInt8, UInt8) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = UInt8((rgb >> 16) & 0xFF)
        let g = UInt8((rgb >> 8) & 0xFF)
        let b = UInt8(rgb & 0xFF)
        return (r, g, b)
    }

    func setForeground(_ hex: String) {
        fgHex = hex
    }

    func setBackground(_ hex: String) {
        bgHex = hex
    }
}
