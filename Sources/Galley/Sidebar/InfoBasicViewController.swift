// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// Info パネル内「Info」サブタブ: File/Document Info/Security/Pages/Features の5セクションを表示
final class InfoBasicViewController: NSViewController, SidebarPanelViewController, ExportableContent {

    private var info: PDFDocumentInfo = .empty
    private var listView: SectionedInfoListView!

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 600))
        self.view = root

        listView = SectionedInfoListView()
        listView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(listView)
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: root.topAnchor),
            listView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
    }

    func reload(document: PDFDocument?, url: URL?) {
        self.info = PDFDocumentInfoBuilder.build(document: document, url: url)
        listView.setInfo(info)
        Log.pdfinfo.info("InfoBasic reload sections=\(self.info.sections.count)")
    }

    func exportedMarkdown() -> String? {
        guard !info.sections.isEmpty else { return nil }
        return PDFInfoExporter.markdown(info, title: "PDF Info")
    }

    func exportedJSON() -> String? {
        guard !info.sections.isEmpty else { return nil }
        return PDFInfoExporter.json(info)
    }
}
