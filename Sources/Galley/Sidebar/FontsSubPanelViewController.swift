// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// Info パネル内「Fonts」サブタブ: pdffonts 相当のフォント情報を表示
final class FontsSubPanelViewController: NSViewController, SidebarPanelViewController, ExportableContent {

    private var listView: SectionedInfoListView!
    private var emptyLabel: NSTextField!
    private var currentInfo: PDFDocumentInfo = .empty
    private var fonts: [CGPDFFontScanner.Font] = []

    override func loadView() {
        let root = NSView()
        self.view = root

        listView = SectionedInfoListView()
        listView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(listView)

        emptyLabel = NSTextField(labelWithString: "")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: root.topAnchor),
            listView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
    }

    func reload(document: PDFDocument?, url: URL?) {
        guard let doc = document else {
            fonts = []
            currentInfo = .empty
            showEmpty("(no document)")
            return
        }
        fonts = CGPDFFontScanner.scan(doc)
        if fonts.isEmpty {
            currentInfo = .empty
            showEmpty("No fonts found in this PDF.")
            return
        }
        currentInfo = buildInfo(from: fonts)
        emptyLabel.isHidden = true
        listView.isHidden = false
        listView.setInfo(currentInfo)
        Log.pdfinfo.info("Fonts scanned count=\(self.fonts.count)")
    }

    private func buildInfo(from fonts: [CGPDFFontScanner.Font]) -> PDFDocumentInfo {
        var sections: [InfoSection] = []
        for f in fonts {
            var rows: [InfoRow] = []
            rows.append(.keyValue(key: "Type", value: f.typeDisplay))
            rows.append(.keyValue(key: "Encoding", value: f.encoding))
            rows.append(.keyValue(key: "Embedded", value: f.isEmbedded ? "Yes" : "No"))
            rows.append(.keyValue(key: "Subset", value: f.subsetPrefix != nil ? "Yes" : "No"))
            rows.append(.keyValue(key: "ToUnicode", value: f.hasToUnicode ? "Yes" : "No"))
            rows.append(.keyValue(key: "Pages", value: Self.formatPageRanges(f.pages)))
            sections.append(InfoSection(id: .fonts, title: f.displayName, rows: rows))
        }
        return PDFDocumentInfo(sections: sections)
    }

    private func showEmpty(_ message: String) {
        emptyLabel.stringValue = message
        emptyLabel.isHidden = false
        listView.isHidden = true
    }

    // MARK: - ExportableContent

    func exportedMarkdown() -> String? {
        guard !currentInfo.sections.isEmpty else { return nil }
        return PDFInfoExporter.markdown(currentInfo, title: "Fonts")
    }

    func exportedJSON() -> String? {
        guard !currentInfo.sections.isEmpty else { return nil }
        return PDFInfoExporter.json(currentInfo)
    }

    // MARK: - Utility

    /// [1,2,3,5,6,8] → "1-3, 5-6, 8"
    static func formatPageRanges(_ pages: [Int]) -> String {
        guard !pages.isEmpty else { return "—" }
        let sorted = Array(Set(pages)).sorted()
        var parts: [String] = []
        var start = sorted[0]
        var prev = sorted[0]
        for p in sorted.dropFirst() {
            if p == prev + 1 { prev = p; continue }
            parts.append(start == prev ? "\(start)" : "\(start)-\(prev)")
            start = p
            prev = p
        }
        parts.append(start == prev ? "\(start)" : "\(start)-\(prev)")
        return parts.joined(separator: ", ")
    }
}
