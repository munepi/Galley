import AppKit
import PDFKit
import CSynctex

// ==========================================
// AppDelegate の拡張: Inverse Search 関連の処理
// (PDF上の Cmd + クリック で Emacs にジャンプする機能)
// ==========================================
extension AppDelegate {

    @objc func handlePageClick(_ sender: NSClickGestureRecognizer) {
        guard NSEvent.modifierFlags.contains(.command) else { return }
        guard let fileURL = self.fileURL else { return }

        guard let view = sender.view as? PDFView else { return }
        let location = sender.location(in: view)
        guard let page = view.page(for: location, nearest: true) else { return }
        let pagePoint = view.convert(location, to: page)
        let pageIndex = view.document?.index(for: page) ?? 0

        guard let scanner = synctex_scanner_new_with_output_file(fileURL.path, nil, 1) else { return }
        defer { synctex_scanner_free(scanner) }

        // PDFKitのY座標(下起点)をSyncTeXのY座標(上起点)に反転
        let bounds = page.bounds(for: .cropBox)
        let synctexY = bounds.maxY - pagePoint.y

        if synctex_edit_query(scanner, Int32(pageIndex + 1), Float(pagePoint.x), Float(synctexY)) > 0 {
            if let node = synctex_scanner_next_result(scanner),
               let cName = synctex_node_get_name(node) {
                openInEmacs(file: String(cString: cName), line: synctex_node_line(node))
            }
        }
    }

    func openInEmacs(file: String, line: Int32) {
        let process = Process()
        let searchPaths = [
            "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient",
            "/opt/homebrew/bin/emacsclient",
            "/usr/local/bin/emacsclient"
        ]
        let executablePath = UserDefaults.standard.string(forKey: "emacsclientPath") ??
                             searchPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ??
                             "emacsclient"

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--no-wait", "+\(line)", file]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        try? process.run()
    }
}
