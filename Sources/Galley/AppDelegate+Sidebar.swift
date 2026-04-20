// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit

extension AppDelegate {

    // MARK: - View メニュー: ⌘I / ⌘B / ⌘N

    @objc func toggleInfoSidebar(_ sender: Any?) {
        sidebarController?.activatePanel(.info)
    }

    @objc func toggleBookmarksSidebar(_ sender: Any?) {
        sidebarController?.activatePanel(.bookmarks)
    }

    @objc func toggleAnnotationsSidebar(_ sender: Any?) {
        sidebarController?.activatePanel(.annotations)
    }

    func validateSidebarMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let ctrl = sidebarController else { return true }
        switch menuItem.action {
        case #selector(toggleInfoSidebar(_:)):
            menuItem.state = (ctrl.isLeftVisible && ctrl.activePanelKind == .info) ? .on : .off
        case #selector(toggleBookmarksSidebar(_:)):
            menuItem.state = (ctrl.isLeftVisible && ctrl.activePanelKind == .bookmarks) ? .on : .off
        case #selector(toggleAnnotationsSidebar(_:)):
            menuItem.state = (ctrl.isLeftVisible && ctrl.activePanelKind == .annotations) ? .on : .off
        default:
            break
        }
        return true
    }

    func validateExportMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let ctrl = sidebarController else { return false }
        let scope = ExportScope(rawValue: menuItem.tag / 10) ?? .all
        switch scope {
        case .all: return ctrl.hasAny()
        case .info: return ctrl.hasInfoBasic()
        case .fonts: return ctrl.hasFonts()
        case .xmp: return ctrl.hasXMP()
        case .bookmarks: return ctrl.hasBookmarks()
        case .annotations: return ctrl.hasAnnotations()
        }
    }

    // MARK: - File メニュー: Export ▸ ...

    /// Export 対象。File メニュー項目の tag から復元する
    enum ExportScope: Int {
        case all = 0
        case info = 1
        case fonts = 2
        case xmp = 3
        case bookmarks = 4
        case annotations = 5

        var fileSuffix: String {
            switch self {
            case .all: return "all"
            case .info: return "info"
            case .fonts: return "fonts"
            case .xmp: return "xmp"
            case .bookmarks: return "bookmarks"
            case .annotations: return "annotations"
            }
        }
    }

    /// tag = scope * 10 + (0=Markdown, 1=JSON)
    static func exportMenuTag(scope: ExportScope, isJSON: Bool) -> Int {
        return scope.rawValue * 10 + (isJSON ? 1 : 0)
    }

    @objc func exportSidebarContent(_ sender: NSMenuItem) {
        let scope = ExportScope(rawValue: sender.tag / 10) ?? .all
        let isJSON = (sender.tag % 10) == 1
        let ext = isJSON ? "json" : "md"

        guard let (content, baseName) = buildExport(scope: scope, isJSON: isJSON) else {
            NSSound.beep()
            Log.pdfinfo.warning("Export skipped: no content for scope=\(scope.rawValue) json=\(isJSON)")
            return
        }
        saveExport(content: content, ext: ext, defaultName: baseName + "." + ext)
    }

    private func buildExport(scope: ExportScope, isJSON: Bool) -> (content: String, baseName: String)? {
        guard let sidebar = sidebarController else { return nil }
        let content: String?
        switch scope {
        case .all:
            content = isJSON ? sidebar.exportAllAsJSON() : sidebar.exportAllAsMarkdown()
        case .info:
            content = isJSON ? sidebar.infoPanel.infoVC.exportedJSON() : sidebar.infoPanel.infoVC.exportedMarkdown()
        case .fonts:
            let vc = sidebar.infoPanel.fontsVC as ExportableContent
            content = isJSON ? vc.exportedJSON() : vc.exportedMarkdown()
        case .xmp:
            content = isJSON ? sidebar.infoPanel.xmpVC.exportedJSON() : sidebar.infoPanel.xmpVC.exportedMarkdown()
        case .bookmarks:
            content = isJSON ? sidebar.bookmarksPanel.exportedJSON() : sidebar.bookmarksPanel.exportedMarkdown()
        case .annotations:
            content = isJSON ? sidebar.annotationsPanel.exportedJSON() : sidebar.annotationsPanel.exportedMarkdown()
        }
        guard let c = content, !c.isEmpty else { return nil }
        return (c, pdfBaseName() + "-" + scope.fileSuffix)
    }

    private func pdfBaseName() -> String {
        if let url = self.fileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return "pdf"
    }

    private func saveExport(content: String, ext: String, defaultName: String) {
        guard let window = self.window else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = [ext]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                Log.pdfinfo.info("Exported to \(url.lastPathComponent, privacy: .public)")
            } catch {
                Log.pdfinfo.error("Export failed: \(error.localizedDescription, privacy: .public)")
                NSSound.beep()
            }
        }
    }
}
