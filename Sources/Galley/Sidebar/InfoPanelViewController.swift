// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

final class InfoPanelViewController: NSViewController {

    private var info: PDFDocumentInfo = .empty
    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 600))
        self.view = root

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .default
        outlineView.floatsGroupRows = false
        outlineView.indentationPerLevel = 0
        outlineView.usesAutomaticRowHeights = true
        outlineView.backgroundColor = .clear
        outlineView.gridStyleMask = []
        outlineView.allowsColumnResizing = true
        outlineView.autoresizesOutlineColumn = false

        let keyCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyCol.title = "Key"
        keyCol.width = 140
        keyCol.minWidth = 60
        keyCol.maxWidth = 260
        outlineView.addTableColumn(keyCol)
        outlineView.outlineTableColumn = keyCol

        let valCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        valCol.title = "Value"
        valCol.minWidth = 100
        valCol.resizingMask = [.autoresizingMask, .userResizingMask]
        outlineView.addTableColumn(valCol)

        outlineView.dataSource = self
        outlineView.delegate = self

        scrollView.documentView = outlineView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        outlineView.expandItem(nil, expandChildren: true)
    }

    func reload(document: PDFDocument?, url: URL?) {
        self.info = PDFDocumentInfoBuilder.build(document: document, url: url)
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
        Log.pdfinfo.info("reload sections=\(self.info.sections.count)")
    }
}

// MARK: - NSOutlineViewDataSource

extension InfoPanelViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return info.sections.count
        }
        if let sec = item as? InfoSection {
            return sec.rows.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return info.sections[index]
        }
        if let sec = item as? InfoSection {
            return RowRef(section: sec, index: index)
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is InfoSection
    }
}

// 子アイテムは struct なので identity を持たせるためラッパー
final class RowRef {
    let section: InfoSection
    let index: Int
    init(section: InfoSection, index: Int) {
        self.section = section
        self.index = index
    }
    var row: InfoRow { section.rows[index] }
}

// MARK: - NSOutlineViewDelegate

extension InfoPanelViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is InfoSection
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        // テキスト選択優先方式 (B): 行選択は無効
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let colID = tableColumn?.identifier.rawValue

        if let sec = item as? InfoSection {
            // Group row: セクション見出し
            if colID == "key" {
                return makeSectionHeaderCell(title: sec.title)
            }
            return makeTextCell(text: "", bold: false)
        }

        if let ref = item as? RowRef {
            switch ref.row {
            case .keyValue(let k, let v):
                if colID == "key" {
                    return makeTextCell(text: k, bold: false, secondary: true)
                } else {
                    return makeTextCell(text: v, bold: false)
                }
            case .longText(let label, let value):
                if colID == "key" {
                    return makeTextCell(text: label, bold: false, secondary: true)
                } else {
                    return makeTextCell(text: value, bold: false, monospace: true)
                }
            }
        }
        return nil
    }

    // MARK: - Cell factories

    private func makeSectionHeaderCell(title: String) -> NSView {
        let container = NSTableCellView()
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        label.textColor = .secondaryLabelColor
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])
        return container
    }

    private func makeTextCell(text: String, bold: Bool, secondary: Bool = false, monospace: Bool = false) -> NSView {
        let container = NSTableCellView()
        let tf = NSTextField()
        tf.stringValue = text
        tf.isEditable = false
        tf.isSelectable = true
        tf.isBordered = false
        tf.drawsBackground = false
        tf.lineBreakMode = .byWordWrapping
        tf.maximumNumberOfLines = 0
        tf.usesSingleLineMode = false
        tf.cell?.wraps = true
        tf.cell?.isScrollable = false
        if monospace {
            tf.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        } else {
            tf.font = bold ? NSFont.boldSystemFont(ofSize: NSFont.systemFontSize) : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        if secondary {
            tf.textColor = .secondaryLabelColor
        }
        tf.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tf)
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            tf.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            tf.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])
        return container
    }
}
