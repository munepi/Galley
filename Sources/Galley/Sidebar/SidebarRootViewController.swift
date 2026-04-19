// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// サイドバー左側のコンテナ。トップレベルパネル（Info/Bookmarks/Annotations）を差し替え表示する
final class SidebarRootViewController: NSViewController {

    private(set) var currentPanel: SidebarPanelViewController?

    override func loadView() {
        let v = NSView()
        self.view = v
    }

    func showPanel(_ panel: SidebarPanelViewController) {
        // 既存パネルを除去
        if let old = currentPanel {
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        // 新パネルを追加
        addChild(panel)
        let pv = panel.view
        pv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pv)
        NSLayoutConstraint.activate([
            pv.topAnchor.constraint(equalTo: view.topAnchor),
            pv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        currentPanel = panel
    }

    func reloadCurrent(document: PDFDocument?, url: URL?) {
        currentPanel?.reload(document: document, url: url)
    }
}
