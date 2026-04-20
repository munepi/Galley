// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import AppKit
import PDFKit

/// Bookmarks パネル: PDF の栞 (outlineRoot) をツリー表示し、クリックでその位置へジャンプ
final class BookmarksPanelViewController: NSViewController, SidebarPanelViewController, ExportableContent {

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

    // MARK: - ExportableContent

    func exportedMarkdown() -> String? {
        guard let root = outlineRoot, root.numberOfChildren > 0 else { return nil }
        var out = "# Bookmarks\n\n"
        for i in 0..<root.numberOfChildren {
            if let child = root.child(at: i) {
                appendMarkdown(outline: child, depth: 0, into: &out)
            }
        }
        return out
    }

    private func appendMarkdown(outline: PDFOutline, depth: Int, into out: inout String) {
        let indent = String(repeating: "  ", count: depth)
        let label = outline.label ?? "(untitled)"
        let pageInfo = pageInfo(for: outline)
        if let p = pageInfo {
            out += "\(indent)- \(label) *(p.\(p))*\n"
        } else {
            out += "\(indent)- \(label)\n"
        }
        for i in 0..<outline.numberOfChildren {
            if let child = outline.child(at: i) {
                appendMarkdown(outline: child, depth: depth + 1, into: &out)
            }
        }
    }

    func exportedJSON() -> String? {
        guard let root = outlineRoot, root.numberOfChildren > 0 else { return nil }
        var children: [[String: Any]] = []
        for i in 0..<root.numberOfChildren {
            if let c = root.child(at: i) {
                children.append(outlineToDict(c))
            }
        }
        let payload: [String: Any] = ["bookmarks": children]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private func outlineToDict(_ outline: PDFOutline) -> [String: Any] {
        var dict: [String: Any] = ["label": outline.label ?? ""]
        if let p = pageInfo(for: outline) {
            dict["page"] = p
        }
        if outline.numberOfChildren > 0 {
            var kids: [[String: Any]] = []
            for i in 0..<outline.numberOfChildren {
                if let c = outline.child(at: i) {
                    kids.append(outlineToDict(c))
                }
            }
            dict["children"] = kids
        }
        return dict
    }

    private func pageInfo(for outline: PDFOutline) -> String? {
        let dest: PDFDestination?
        if let d = outline.destination {
            dest = d
        } else if let a = outline.action as? PDFActionGoTo {
            dest = a.destination
        } else {
            dest = nil
        }
        guard let page = dest?.page, let doc = page.document else { return nil }
        let index = doc.index(for: page)
        return page.label ?? "\(index + 1)"
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
