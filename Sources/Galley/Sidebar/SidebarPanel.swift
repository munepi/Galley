// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// ⌘I / ⌘B / ⌘N で切り替える左サイドバーのトップレベルパネル種別
enum SidebarPanelKind: String {
    case info
    case bookmarks
    case annotations
}

/// サイドバー内のパネルが満たすべき共通インターフェース
protocol SidebarPanelViewController: NSViewController {
    func reload(document: PDFDocument?, url: URL?)
}

/// 現在のパネル/サブタブの内容を Markdown / JSON に書き出せることを示すプロトコル
protocol ExportableContent: AnyObject {
    func exportedMarkdown() -> String?
    func exportedJSON() -> String?
}
