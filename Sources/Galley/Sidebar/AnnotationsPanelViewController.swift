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

/// Annotations パネル: PDF内の注釈を一覧表示し、クリックで該当位置へジャンプ
final class AnnotationsPanelViewController: NSViewController, SidebarPanelViewController, ExportableContent {

    var onNavigate: ((PDFDestination) -> Void)?

    private var items: [AnnotationItem] = []
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var emptyLabel: NSTextField!

    /// ノイズ源となる注釈タイプを除外
    private static let excludedTypes: Set<String> = ["Link", "Widget", "Popup"]

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

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowSizeStyle = .default
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.usesAutomaticRowHeights = true

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ann"))
        col.minWidth = 100
        col.resizingMask = [.autoresizingMask, .userResizingMask]
        tableView.addTableColumn(col)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked(_:))

        // 右クリックメニュー
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy Content", action: #selector(copyContent(_:)), keyEquivalent: "")
        for mi in menu.items { mi.target = self }
        tableView.menu = menu

        scrollView.documentView = tableView

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
        items = collectItems(from: document)
        if document == nil {
            emptyLabel.stringValue = "(no document)"
            emptyLabel.isHidden = false
            scrollView.isHidden = true
        } else if items.isEmpty {
            emptyLabel.stringValue = "No annotations in this PDF."
            emptyLabel.isHidden = false
            scrollView.isHidden = true
        } else {
            emptyLabel.isHidden = true
            scrollView.isHidden = false
        }
        tableView.reloadData()
        Log.pdfinfo.info("Annotations reload count=\(self.items.count)")
    }

    private func collectItems(from document: PDFDocument?) -> [AnnotationItem] {
        guard let doc = document else { return [] }
        var out: [AnnotationItem] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let label = page.label ?? "\(i + 1)"
            for ann in page.annotations {
                let type = ann.type ?? "Unknown"
                if Self.excludedTypes.contains(type) { continue }
                let preview = previewText(for: ann, page: page)
                out.append(AnnotationItem(
                    pageIndex: i,
                    pageLabel: label,
                    typeName: type,
                    preview: preview,
                    annotation: ann
                ))
            }
        }
        // ページ順＋ページ内は top → bottom の順
        out.sort { a, b in
            if a.pageIndex != b.pageIndex { return a.pageIndex < b.pageIndex }
            let ay = a.annotation?.bounds.maxY ?? 0
            let by = b.annotation?.bounds.maxY ?? 0
            return ay > by  // PDF座標は下原点なので maxY 大 = ページ上部
        }
        return out
    }

    private func previewText(for ann: PDFAnnotation, page: PDFPage) -> String {
        // 1. contents (付箋・FreeTextはここに入る)
        if let c = ann.contents, !c.isEmpty {
            return c.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        }
        // 2. ハイライト等のマークアップは覆ったテキストを取得
        let markupTypes: Set<String> = ["Highlight", "Underline", "StrikeOut", "Squiggly"]
        if let type = ann.type, markupTypes.contains(type) {
            if let sel = page.selection(for: ann.bounds), let s = sel.string, !s.isEmpty {
                return s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            }
        }
        return "(no text)"
    }

    @objc private func rowClicked(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, row < items.count else { return }
        let item = items[row]
        guard let ann = item.annotation, let page = ann.page else { return }
        // 注釈の上端（PDF座標は下原点）にジャンプ
        let point = CGPoint(x: ann.bounds.minX, y: ann.bounds.maxY)
        let dest = PDFDestination(page: page, at: point)
        onNavigate?(dest)
    }

    private func targetRow() -> Int {
        // 右クリック行優先、なければ選択行
        let clicked = tableView.clickedRow
        if clicked >= 0 { return clicked }
        return tableView.selectedRow
    }

    @objc private func copyContent(_ sender: Any?) {
        let row = targetRow()
        guard row >= 0, row < items.count else { return }
        let text = items[row].preview
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// ⌘C でのコピーに対応（NSTableView が pasteboardWriterForRow を通じて処理）
    @objc func copy(_ sender: Any?) {
        copyContent(sender)
    }

    // MARK: - ExportableContent

    func exportedMarkdown() -> String? {
        guard !items.isEmpty else { return nil }
        var out = "# Annotations\n\n"
        for item in items {
            out += "- **p.\(item.pageLabel)** `[\(item.typeName)]` \(item.preview.replacingOccurrences(of: "\n", with: " "))\n"
        }
        return out
    }

    func exportedJSON() -> String? {
        guard !items.isEmpty else { return nil }
        let arr: [[String: Any]] = items.map { item in
            [
                "page": item.pageLabel,
                "pageIndex": item.pageIndex + 1,
                "type": item.typeName,
                "content": item.preview
            ]
        }
        let payload: [String: Any] = ["annotations": arr]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}

struct AnnotationItem {
    let pageIndex: Int
    let pageLabel: String
    let typeName: String
    let preview: String
    weak var annotation: PDFAnnotation?
}

extension AnnotationsPanelViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }
}

extension AnnotationsPanelViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let cell = NSTableCellView()

        let header = NSTextField(labelWithString: "p.\(item.pageLabel)  [\(item.typeName)]")
        header.font = NSFont.systemFont(ofSize: NSFont.systemFontSize - 1)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingTail
        header.maximumNumberOfLines = 1
        header.isSelectable = false
        header.isEditable = false
        header.isBordered = false
        header.drawsBackground = false
        header.translatesAutoresizingMaskIntoConstraints = false

        let body = WrappingLabel(wrappingLabelWithString: item.preview)
        body.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        body.lineBreakMode = .byWordWrapping
        body.maximumNumberOfLines = 0
        body.isSelectable = false
        body.isEditable = false
        body.isBordered = false
        body.drawsBackground = false
        body.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(header)
        cell.addSubview(body)
        cell.textField = body

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            header.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),

            body.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2),
            body.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            body.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            body.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4),
        ])
        return cell
    }
}
