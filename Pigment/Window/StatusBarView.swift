import AppKit

final class StatusBarView: NSView {

    private let cursorLabel: NSTextField
    private let selectionLabel: NSTextField
    private let canvasLabel: NSTextField

    override init(frame frameRect: NSRect) {
        let makeLabel = { () -> NSTextField in
            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .secondaryLabelColor
            return label
        }

        cursorLabel = makeLabel()
        selectionLabel = makeLabel()
        canvasLabel = makeLabel()

        super.init(frame: frameRect)

        let separator = NSBox()
        separator.boxType = .separator

        [cursorLabel, selectionLabel, canvasLabel].forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            cursorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            cursorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            cursorLabel.widthAnchor.constraint(equalToConstant: 100),

            selectionLabel.leadingAnchor.constraint(equalTo: cursorLabel.trailingAnchor, constant: 12),
            selectionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectionLabel.widthAnchor.constraint(equalToConstant: 100),

            canvasLabel.leadingAnchor.constraint(equalTo: selectionLabel.trailingAnchor, constant: 12),
            canvasLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            canvasLabel.widthAnchor.constraint(equalToConstant: 120),
        ])

        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(cursorX: Int?, cursorY: Int?, selectionW: Int?, selectionH: Int?, canvasW: Int, canvasH: Int) {
        if let cx = cursorX, let cy = cursorY {
            cursorLabel.stringValue = "\(cx),\(cy)"
        } else {
            cursorLabel.stringValue = ""
        }

        if let sw = selectionW, let sh = selectionH {
            selectionLabel.stringValue = "\(sw) x \(sh)"
        } else {
            selectionLabel.stringValue = ""
        }

        canvasLabel.stringValue = "\(canvasW) x \(canvasH)"
    }
}
