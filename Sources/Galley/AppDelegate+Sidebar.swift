// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit

extension AppDelegate {

    @objc func toggleInfoSidebar(_ sender: Any?) {
        sidebarController?.toggleLeft()
    }

    func validateSidebarMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleInfoSidebar(_:)) {
            menuItem.state = (sidebarController?.isLeftVisible == true) ? .on : .off
        }
        return true
    }
}
