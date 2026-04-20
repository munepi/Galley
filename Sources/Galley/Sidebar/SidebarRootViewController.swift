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

/// サイドバー左側のコンテナ。共通の上部バー（Exportドロップダウン）と、トップレベルパネルを差し替え表示する領域を持つ
final class SidebarRootViewController: NSViewController {

    private(set) var currentPanel: SidebarPanelViewController?

    private var topBar: NSView!
    private var exportButton: NSPopUpButton!
    private var contentContainer: NSView!

    override func loadView() {
        let v = NSView()
        self.view = v

        topBar = NSView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(topBar)

        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(contentContainer)

        exportButton = NSPopUpButton(frame: .zero, pullsDown: true)
        exportButton.bezelStyle = .rounded
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        rebuildExportMenu()
        topBar.addSubview(exportButton)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: v.safeAreaLayoutGuide.topAnchor, constant: 6),
            topBar.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 8),
            topBar.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -8),
            topBar.heightAnchor.constraint(equalToConstant: 24),

            exportButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            exportButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            exportButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),

            contentContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 6),
            contentContainer.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: v.bottomAnchor),
        ])
    }

    func showPanel(_ panel: SidebarPanelViewController) {
        if let old = currentPanel {
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        addChild(panel)
        let pv = panel.view
        pv.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(pv)
        NSLayoutConstraint.activate([
            pv.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            pv.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            pv.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            pv.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        currentPanel = panel
        updateExportButtonAvailability()
    }

    func reloadCurrent(document: PDFDocument?, url: URL?) {
        currentPanel?.reload(document: document, url: url)
        updateExportButtonAvailability()
    }

    // MARK: - Export button

    private func rebuildExportMenu() {
        let menu = NSMenu()
        // pullsDown: 先頭はボタンラベル
        let titleItem = NSMenuItem(title: "Copy", action: nil, keyEquivalent: "")
        menu.addItem(titleItem)

        let mdItem = NSMenuItem(title: "Copy as Markdown", action: #selector(copyMarkdownAction(_:)), keyEquivalent: "")
        mdItem.target = self
        menu.addItem(mdItem)

        let jsonItem = NSMenuItem(title: "Copy as JSON", action: #selector(copyJSONAction(_:)), keyEquivalent: "")
        jsonItem.target = self
        menu.addItem(jsonItem)

        exportButton.menu = menu
    }

    private func updateExportButtonAvailability() {
        let exportable = currentPanel as? ExportableContent
        exportButton.isEnabled = exportable != nil
    }

    @objc private func copyMarkdownAction(_ sender: Any?) {
        guard let exportable = currentPanel as? ExportableContent,
              let md = exportable.exportedMarkdown() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(md, forType: .string)
        Log.pdfinfo.info("Exported Markdown to clipboard (\(md.count) chars)")
    }

    @objc private func copyJSONAction(_ sender: Any?) {
        guard let exportable = currentPanel as? ExportableContent,
              let json = exportable.exportedJSON() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(json, forType: .string)
        Log.pdfinfo.info("Exported JSON to clipboard (\(json.count) chars)")
    }
}
