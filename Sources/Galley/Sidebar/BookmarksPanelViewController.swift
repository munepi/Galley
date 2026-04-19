// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// Bookmarks パネル: PDF の栞 (outlineRoot) をツリー表示し、クリックでその位置へジャンプ
final class BookmarksPanelViewController: NSViewController, SidebarPanelViewController {

    /// 栞クリック時に通知するコールバック（SidebarController 経由で AppDelegate が受ける）
    var onNavigate: ((PDFDestination) -> Void)?

    private var outlineRoot: PDFOutline?
    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var emptyLabel: NSTextField!

    override func loadView() {
        let root = NSView()
        self.view = root

        emptyLabel = NSTextField(labelWithString: "")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        root.addSubview(emptyLabel)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .default
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.backgroundColor = .clear
        outlineView.gridStyleMask = []
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("label"))
        col.title = "Bookmark"
        col.minWidth = 60
        col.resizingMask = [.autoresizingMask, .userResizingMask]
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col

        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(rowClicked(_:))

        scrollView.documentView = outlineView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
    }

    func reload(document: PDFDocument?, url: URL?) {
        outlineRoot = document?.outlineRoot
        let count = outlineRoot?.numberOfChildren ?? 0
        if document == nil {
            emptyLabel.stringValue = "(no document)"
            emptyLabel.isHidden = false
            scrollView.isHidden = true
        } else if count == 0 {
            emptyLabel.stringValue = "No bookmarks in this PDF."
            emptyLabel.isHidden = false
            scrollView.isHidden = true
        } else {
            emptyLabel.isHidden = true
            scrollView.isHidden = false
        }
        outlineView.reloadData()
        expandTopLevel()
        Log.pdfinfo.info("Bookmarks reload topLevel=\(count)")
    }

    private func expandTopLevel() {
        guard let root = outlineRoot else { return }
        for i in 0..<root.numberOfChildren {
            if let child = root.child(at: i) {
                outlineView.expandItem(child)
            }
        }
    }

    @objc private func rowClicked(_ sender: Any?) {
        let row = outlineView.clickedRow
        guard row >= 0,
              let o = outlineView.item(atRow: row) as? PDFOutline else { return }
        if let dest = o.destination {
            onNavigate?(dest)
        } else if let action = o.action as? PDFActionGoTo {
            onNavigate?(action.destination)
        }
    }
}

extension BookmarksPanelViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return outlineRoot?.numberOfChildren ?? 0
        }
        if let o = item as? PDFOutline {
            return o.numberOfChildren
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return outlineRoot!.child(at: index)!
        }
        return (item as! PDFOutline).child(at: index)!
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let o = item as? PDFOutline else { return false }
        return o.numberOfChildren > 0
    }
}

extension BookmarksPanelViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let o = item as! PDFOutline
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: o.label ?? "(untitled)")
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isSelectable = false
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
