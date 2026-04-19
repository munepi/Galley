// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit

extension AppDelegate {

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
}
