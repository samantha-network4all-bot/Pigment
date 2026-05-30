import Foundation

struct ToolOptions: Codable {
    var lineWidth: Int = 1
    var brushSize: Int = 1
    var eraserSize: Int = 1
    var airbrushSize: Int = 1
    var fillMode: String = "outlineFill"
    var transparentSelection: Bool = false
    var textStyle: String = ""
    var magnifierZoom: Int = 100
}
