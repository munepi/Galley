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

// ==========================================
// AppDelegate の拡張: SyncTeX メニューおよびエディタ設定関連
// ==========================================
extension AppDelegate {

    // --- メニューからのエディタ選択アクション ---
    @objc func changeSyncTexEditor(_ sender: NSMenuItem) {
        let editor: String
        switch sender.title {
        case "Visual Studio Code":
            editor = "vscode"
        case "Custom":
            editor = "custom"
        default:
            editor = "emacs"
        }
        UserDefaults.standard.set(editor, forKey: "syncTexEditor")
    }

    // --- SyncTeXメニューのチェックマーク状態の管理 ---
    func validateSyncTexMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let currentEditor = UserDefaults.standard.string(forKey: "syncTexEditor") ?? "emacs"

        switch menuItem.title {
        case "Emacs":
            menuItem.state = (currentEditor == "emacs") ? .on : .off
        case "Visual Studio Code":
            menuItem.state = (currentEditor == "vscode") ? .on : .off
        case "Custom":
            menuItem.state = (currentEditor == "custom") ? .on : .off
        default:
            break
        }

        return true
    }
}
