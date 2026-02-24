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
        self.window?.title = url.lastPathComponent
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
                }
                self.swapWorkItem = swapItem

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: swapItem)
            }
        }
    }
}
