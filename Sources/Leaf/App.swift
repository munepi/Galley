import SwiftUI
import AppKit
import PDFKit

@main
struct LeafApp {
    static func main() {
        // NSApplication.sharedが呼ばれて描画エンジンが起動する「前」に設定
        UserDefaults.standard.set(0, forKey: "AppleFontSmoothing")
        UserDefaults.standard.set(true, forKey: "CGFontRenderingFontSmoothingDisabled")

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        let mainMenu = NSMenu()

        // --- 1. App メニュー ---
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Leaf", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator()) // 区切り線
        appMenu.addItem(withTitle: "Quit Leaf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // --- 2. File メニュー ---
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Open PDF file...", action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Print PDF file...", action: #selector(AppDelegate.printDocument(_:)), keyEquivalent: "p")

        // --- 3. Edit メニュー (Cmd + C 用) ---
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Copy", action: #selector(PDFView.copy(_:)), keyEquivalent: "c")

        // --- 4. View メニュー (Zoom系 & ページナビゲーション系) ---
        let viewMenu = NSMenu(title: "View")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu

        // ズーム系
        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(AppDelegate.zoomInAction(_:)), keyEquivalent: "+")
        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(AppDelegate.zoomOutAction(_:)), keyEquivalent: "-")
        let autoResizeItem = NSMenuItem(title: "Automatically Resize", action: #selector(AppDelegate.autoResizeAction(_:)), keyEquivalent: "_")
        let actualSizeItem = NSMenuItem(title: "Actual Size", action: #selector(AppDelegate.actualSizeAction(_:)), keyEquivalent: "0")

        viewMenu.addItem(zoomInItem)
        viewMenu.addItem(zoomOutItem)
        viewMenu.addItem(actualSizeItem)
        viewMenu.addItem(autoResizeItem)

        viewMenu.addItem(NSMenuItem.separator())

        // 表示モード系
        let singlePageItem = NSMenuItem(title: "Single Page", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "")
        let singlePageContinuousItem = NSMenuItem(title: "Single Page Continuous", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "")
        let twoPagesItem = NSMenuItem(title: "Two Pages", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "")
        let twoPagesContinuousItem = NSMenuItem(title: "Two Pages Continuous", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "")

        viewMenu.addItem(singlePageItem)
        viewMenu.addItem(singlePageContinuousItem)
        viewMenu.addItem(twoPagesItem)
        viewMenu.addItem(twoPagesContinuousItem)

        viewMenu.addItem(NSMenuItem.separator())

        // トグル系
        let bookModeItem = NSMenuItem(title: "Book Mode", action: #selector(AppDelegate.toggleBookModeAction(_:)), keyEquivalent: "")
        let rtlItem = NSMenuItem(title: "Right-To-Left", action: #selector(AppDelegate.toggleRTLAction(_:)), keyEquivalent: "")

        viewMenu.addItem(bookModeItem)
        viewMenu.addItem(rtlItem)

        viewMenu.addItem(NSMenuItem.separator())

        // ページナビゲーション系
        let nextPageItem = NSMenuItem(title: "Next Page", action: #selector(AppDelegate.nextPageAction(_:)), keyEquivalent: " ")
        nextPageItem.keyEquivalentModifierMask = []

        let nextPageAltItem = NSMenuItem(title: "Next Page", action: #selector(AppDelegate.nextPageAction(_:)), keyEquivalent: "j")
        nextPageAltItem.keyEquivalentModifierMask = [.option]
        nextPageAltItem.isAlternate = true
        nextPageAltItem.isHidden = true

        let prevPageItem = NSMenuItem(title: "Previous Page", action: #selector(AppDelegate.previousPageAction(_:)), keyEquivalent: " ")
        prevPageItem.keyEquivalentModifierMask = [.shift]

        let prevPageAltItem = NSMenuItem(title: "Previous Page", action: #selector(AppDelegate.previousPageAction(_:)), keyEquivalent: "k")
        prevPageAltItem.keyEquivalentModifierMask = [.option]
        prevPageAltItem.isAlternate = true
        prevPageAltItem.isHidden = true

        viewMenu.addItem(nextPageItem)
        viewMenu.addItem(nextPageAltItem)
        viewMenu.addItem(prevPageItem)
        viewMenu.addItem(prevPageAltItem)

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(editMenuItem)
        mainMenu.addItem(viewMenuItem)

        app.mainMenu = mainMenu
        app.setActivationPolicy(.regular)
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    var container: NSView!
    var pdfViewA: LeafPDFView!
    var pdfViewB: LeafPDFView!
    var isShowingA = true

    var activePDFView: LeafPDFView { isShowingA ? pdfViewA : pdfViewB }
    var hiddenPDFView: LeafPDFView { isShowingA ? pdfViewB : pdfViewA }

    var timer: Timer?
    var lastUpdate: Date?
    var fileURL: URL?
    var reloadWorkItem: DispatchWorkItem?
    var swapWorkItem: DispatchWorkItem?

    var isDebugMode: Bool {
        return UserDefaults.standard.bool(forKey: "debugMode")
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        self.setupForwardSearch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        pdfViewA = LeafPDFView()
        pdfViewB = LeafPDFView()

        for view in [pdfViewA, pdfViewB] {
            view!.autoScales = true
            view!.displayMode = .singlePageContinuous
            view!.backgroundColor = NSColor.windowBackgroundColor

            let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handlePageClick(_:)))
            view!.addGestureRecognizer(clickRecognizer)
        }

        // ページ移動イベントを監視してタイトルを更新するように設定
        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChanged(_:)), name: .PDFViewPageChanged, object: nil)

        container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 1000))
        container.wantsLayer = true

        pdfViewA.frame = container.bounds
        pdfViewA.autoresizingMask = [.width, .height]
        pdfViewB.frame = container.bounds
        pdfViewB.autoresizingMask = [.width, .height]

        container.addSubview(pdfViewB)
        container.addSubview(pdfViewA)

        let window = NSWindow(
            contentRect: container.bounds,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.contentView = container
        self.window = window

        if let url = self.fileURL {
            loadPDF(url: url)
        } else if CommandLine.arguments.count > 1 {
            loadPDF(url: URL(fileURLWithPath: CommandLine.arguments[1]).absoluteURL)
        } else {
            window.title = "Leaf"
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.fileURL == nil { self.openDocument(nil) }
            }
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
