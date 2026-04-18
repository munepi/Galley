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
import CSynctex

// ==========================================
// AppDelegate の拡張: Inverse Search 関連の処理
// (PDF上の Cmd + クリック で エディタ にジャンプする機能)
// ==========================================
extension AppDelegate {

    func performInverseSearch(event: NSEvent, view: PDFView) {
        guard let fileURL = self.fileURL else { return }

        // NSEvent から直接座標を取り出す
        let location = view.convert(event.locationInWindow, from: nil)
        guard let page = view.page(for: location, nearest: true) else { return }
        let pagePoint = view.convert(location, to: page)
        let pageIndex = view.document?.index(for: page) ?? 0

        guard let scanner = synctex_scanner_new_with_output_file(fileURL.path, nil, 1) else { return }
        defer { synctex_scanner_free(scanner) }

        let bounds = page.bounds(for: .cropBox)
        let synctexY = bounds.maxY - pagePoint.y

        let pdfName = fileURL.lastPathComponent
        Log.inverseSearch.debug("Inverse Search ➔ PDF: \(pdfName, privacy: .public)")

        if synctex_edit_query(scanner, Int32(pageIndex + 1), Float(pagePoint.x), Float(synctexY)) > 0 {
            if let node = synctex_scanner_next_result(scanner),
               let cName = synctex_node_get_name(node) {

                let srcPath = String(cString: cName)
                let srcName = (srcPath as NSString).lastPathComponent
                let line = synctex_node_line(node)

                let detailMessage = """
                Page: \(pageIndex + 1)
                Click pt: X=\(String(format: "%.1f", pagePoint.x)), Y=\(String(format: "%.1f", pagePoint.y))
                SyncTeX Y: \(String(format: "%.1f", synctexY))
                Target: \(srcName) | Line: \(line)
                """
                Log.inverseSearch.debug("\(detailMessage, privacy: .public)")

                // --- 選択されているエディタに応じて処理を分岐 ---
                let selectedEditor = UserDefaults.standard.string(forKey: "syncTexEditor") ?? "emacs"
                switch selectedEditor {
                case "vscode":
                    openInVSCode(file: srcPath, line: line)
                case "custom":
                    openInCustom(file: srcPath, line: line)
                default:
                    openInEmacs(file: srcPath, line: line)
                }

            } else {
                Log.inverseSearch.error("SyncTeX matched no nodes.")
            }
        } else {
            Log.inverseSearch.error("SyncTeX query failed.")
        }
    }

    // --- Emacs で開く ---
    func openInEmacs(file: String, line: Int32) {
        let process = Process()
        let searchPaths = [
            "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient",
            "/opt/homebrew/bin/emacsclient",
            "/usr/local/bin/emacsclient"
        ]

        // 空文字列かどうかの判定を追加
        let savedPath = UserDefaults.standard.string(forKey: "emacsclientPath") ?? ""
        let executablePath = savedPath.isEmpty
            ? (searchPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? "emacsclient")
            : savedPath

        let commandString = "\(executablePath) --no-wait +\(line) '\(file)'"
        Log.inverseSearch.debug("Executing Emacs Command: \(commandString, privacy: .public)")

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--no-wait", "+\(line)", file]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        try? process.run()
    }

    // --- VSCode で開く ---
    func openInVSCode(file: String, line: Int32) {
        let urlString = "vscode://file\(file):\(line)"
        Log.inverseSearch.debug("Opening VSCode URL: \(urlString, privacy: .public)")

        // パスにスペース等が含まれている場合のためのエンコーディング
        if let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encodedString) {
            NSWorkspace.shared.open(url)
        }
    }

    // --- Customエディタ で開く ---
    func openInCustom(file: String, line: Int32) {
        // UserDefaultsからカスタムコマンドのテンプレートを読み込む
        guard let commandTemplate = UserDefaults.standard.string(forKey: "customEditorCommand"), !commandTemplate.isEmpty else {
            DispatchQueue.main.async {
                self.showNotification("Custom Editor is not configured.\nPlease set 'customEditorCommand' via defaults.")
            }
            return
        }

        // placefolder の置換 (%file と %line)
        let command = commandTemplate
            .replacingOccurrences(of: "%file", with: file)
            .replacingOccurrences(of: "%line", with: "\(line)")

        Log.inverseSearch.debug("Executing Custom Command: \(command, privacy: .public)")

        // /bin/sh 経由でコマンドを実行
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        do {
            try process.run()
        } catch {
            Log.inverseSearch.error("Failed to execute custom command: \(error.localizedDescription, privacy: .public)")
        }
    }
}
