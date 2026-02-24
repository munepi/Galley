import AppKit

// ==========================================
// AppDelegate の拡張: View メニュー関連 (Zoom系 & ページナビゲーション系)
// ==========================================
extension AppDelegate {
    // Zoom系
    @objc func zoomInAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = false
            view?.zoomIn(sender)
        }
    }

    @objc func zoomOutAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = false
            view?.zoomOut(sender)
        }
    }

    @objc func autoResizeAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = true
            view?.layoutDocumentView()
        }
    }

    @objc func actualSizeAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = false
            view?.scaleFactor = 1.0
        }
    }

    // ページナビゲーション系
    @objc func nextPageAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.goToNextPage(sender)
        }
    }

    @objc func previousPageAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.goToPreviousPage(sender)
        }
    }
}
