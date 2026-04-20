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

}
