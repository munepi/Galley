import AppKit
import PDFKit

// ==========================================
// AppDelegate の拡張: View メニュー関連 (Zoom系 & ページナビゲーション系 & 表示モード)
// ==========================================
extension AppDelegate: NSMenuItemValidation {

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

    // 表示モード変更系
    @objc func changeDisplayMode(_ sender: NSMenuItem) {
        let mode: PDFDisplayMode
        switch sender.title {
        case "Single Page":
            mode = .singlePage
        case "Single Page Continuous":
            mode = .singlePageContinuous
        case "Two Pages":
            mode = .twoUp
        case "Two Pages Continuous":
            mode = .twoUpContinuous
        default:
            return
        }

        // 変更されたモードを UserDefaults に保存
        UserDefaults.standard.set(mode.rawValue, forKey: "displayMode")

        // リロード時の不整合を防ぐため、A/B両方のビューに反映する
        for view in [pdfViewA, pdfViewB] {
            view?.displayMode = mode
        }
    }

    @objc func toggleBookModeAction(_ sender: NSMenuItem) {
        let newState = !(self.activePDFView.displaysAsBook)

        // Book Modeの状態を UserDefaults に保存
        UserDefaults.standard.set(newState, forKey: "displaysAsBook")

        for view in [pdfViewA, pdfViewB] {
            view?.displaysAsBook = newState
        }
    }

    @objc func toggleRTLAction(_ sender: NSMenuItem) {
        let newState = !(self.activePDFView.displaysRTL)

        // RTLの状態を UserDefaults に保存
        UserDefaults.standard.set(newState, forKey: "displaysRTL")

        for view in [pdfViewA, pdfViewB] {
            view?.displaysRTL = newState
        }
    }

    // メニューのチェックマーク状態の管理
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // activePDFViewを基準に、現在どのモードになっているかを判定してメニューの✓を制御
        let currentView = self.activePDFView

        switch menuItem.title {
        case "Single Page":
            menuItem.state = (currentView.displayMode == .singlePage) ? .on : .off
        case "Single Page Continuous":
            menuItem.state = (currentView.displayMode == .singlePageContinuous) ? .on : .off
        case "Two Pages":
            menuItem.state = (currentView.displayMode == .twoUp) ? .on : .off
        case "Two Pages Continuous":
            menuItem.state = (currentView.displayMode == .twoUpContinuous) ? .on : .off

        case "Book Mode":
            menuItem.state = currentView.displaysAsBook ? .on : .off
        case "Right-To-Left":
            menuItem.state = currentView.displaysRTL ? .on : .off

        default:
            break
        }

        return true
    }
}
