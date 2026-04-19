// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// Annotations パネル: PDF内の注釈を一覧表示し、クリックで該当位置へジャンプ
final class AnnotationsPanelViewController: NSViewController, SidebarPanelViewController {

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

        let body = NSTextField(labelWithString: item.preview)
        body.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        body.lineBreakMode = .byTruncatingTail
        body.maximumNumberOfLines = 2
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
