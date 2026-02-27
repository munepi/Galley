import AppKit
import PDFKit

// ==========================================
// AppDelegate の拡張: File メニューおよびファイル管理関連
// ==========================================
extension AppDelegate {

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["pdf"]
        if panel.runModal() == .OK, let url = panel.url { self.loadPDF(url: url) }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename).absoluteURL
        self.fileURL = url

        guard self.pdfViewA != nil else {
            return true
        }

        loadPDF(url: url)

        return true
    }

    func loadPDF(url: URL) {
        if let modal = NSApp.modalWindow, modal is NSOpenPanel {
            NSApp.stopModal()
            modal.close()
        }
        self.fileURL = url.absoluteURL
        guard let document = PDFDocument(url: url) else { return }

        self.activePDFView.document = document

        self.updateWindowTitle()

        self.timer?.invalidate()
        startMonitoring(url: url)
    }

    @objc func printDocument(_ sender: Any?) {
        guard let document = self.activePDFView.document,
              let window = self.window else { return }

        let printInfo = NSPrintInfo.shared
        let printOp = document.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: true)
        printOp?.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    // --- ファイル監視と自動リロード機構 ---
    func startMonitoring(url: URL) {
        let path = url.path
        self.lastUpdate = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)

        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self,
                  let currentModDate = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date),
                  let lastMod = self.lastUpdate,
                  currentModDate > lastMod else { return }

            self.lastUpdate = currentModDate
            self.reloadWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.reloadPDF()
            }
            self.reloadWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
        }
    }

    func reloadPDF() {
        guard let url = self.fileURL else { return }

        let activeView = self.activePDFView
        let hiddenView = self.hiddenPDFView

        var currentPageIndex = 0
        var currentPoint = CGPoint.zero
        if let dest = activeView.currentDestination, let page = dest.page, let doc = activeView.document {
            currentPageIndex = doc.index(for: page)
            currentPoint = dest.point
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let newDocument = PDFDocument(data: data),
                  newDocument.pageCount > 0 else { return }

            DispatchQueue.main.async {
                hiddenView.document = newDocument
                if currentPageIndex < newDocument.pageCount,
                   let newPage = newDocument.page(at: currentPageIndex) {
                    let newDest = PDFDestination(page: newPage, at: currentPoint)
                    hiddenView.go(to: newDest)
                }

                hiddenView.autoScales = activeView.autoScales
                if !activeView.autoScales {
                    hiddenView.scaleFactor = activeView.scaleFactor
                }

                self.swapWorkItem?.cancel()
                let swapItem = DispatchWorkItem {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)

                    hiddenView.removeFromSuperview()
                    self.container.addSubview(hiddenView)

                    self.isShowingA.toggle()

                    activeView.document = nil
                    self.window?.makeFirstResponder(hiddenView)

                    CATransaction.commit()

                    self.updateWindowTitle()
                }
                self.swapWorkItem = swapItem

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: swapItem)
            }
        }
    }

    @objc func handlePageChanged(_ notification: Notification) {
        updateWindowTitle()
    }

    func updateWindowTitle() {
        guard let window = self.window,
              let url = self.fileURL,
              let document = activePDFView.document else { return }

        let fileName = url.lastPathComponent
        let totalPages = document.pageCount

        // 現在表示されているページ番号を取得 (0始まりなので+1する)
        // currentPageが取得できない場合(nilの場合)は暫定で1ページ目とする
        let currentPage = activePDFView.currentPage ?? document.page(at: 0)
        let physicalPage = (currentPage != nil) ? (document.index(for: currentPage!) + 1) : 1

        // 論理ページ(label)の取得と表示の分岐
        if let page = currentPage, let label = page.label, label != "\(physicalPage)" {
            // 論理ページが存在し、かつ物理ページと異なる場合 (例: iv, cover, ☃ など)
            window.title = "\(fileName) - Page \(label) (\(physicalPage)/\(totalPages))"
        } else {
            // 論理ページが設定されていない、または物理ページと一致する場合
            window.title = "\(fileName) - Page \(physicalPage)/\(totalPages)"
        }
    }

}
