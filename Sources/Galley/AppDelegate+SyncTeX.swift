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
