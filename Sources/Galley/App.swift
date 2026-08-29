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

import SwiftUI
import AppKit
import PDFKit
import Sparkle

@main
struct GalleyApp {
    static func main() {
        // NSApplication.sharedが呼ばれて描画エンジンが起動する「前」に設定
        UserDefaults.standard.set(0, forKey: "AppleFontSmoothing")
        UserDefaults.standard.set(true, forKey: "CGFontRenderingFontSmoothingDisabled")

        // UserDefaultsの初期値
        UserDefaults.standard.register(defaults: [
            "displayMode": PDFDisplayMode.singlePageContinuous.rawValue,
            "displaysAsBook": false,
            "displaysRTL": false,
            "pageColorMode": PageColorMode.normal.rawValue,
            "syncTexEditor": "emacs",
            "emacsclientPath": "",
            "vimtexFlavor": "auto",
            "vimPath": "",
            "nvimPath": "",
            "customEditorCommand": ""
        ])

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        let mainMenu = NSMenu()

        // --- 1. App メニュー ---
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Galley", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator()) // 区切り線

        // Sparkle: Check for Updates...
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = delegate.updaterController
        appMenu.addItem(checkForUpdatesItem)
        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(withTitle: "Quit Galley", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // --- 2. File メニュー ---
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Open PDF file...", action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())

        // Export サブメニュー
        let exportItem = NSMenuItem(title: "Export", action: nil, keyEquivalent: "")
        let exportMenu = NSMenu(title: "Export")
        exportItem.submenu = exportMenu

        func addExport(_ title: String, scope: AppDelegate.ExportScope, isJSON: Bool) {
            let item = NSMenuItem(title: title,
                                  action: #selector(AppDelegate.exportSidebarContent(_:)),
                                  keyEquivalent: "")
            item.tag = AppDelegate.exportMenuTag(scope: scope, isJSON: isJSON)
            exportMenu.addItem(item)
        }

        addExport("All as Markdown...", scope: .all, isJSON: false)
        addExport("All as JSON...", scope: .all, isJSON: true)
        exportMenu.addItem(NSMenuItem.separator())
        addExport("Info as Markdown...", scope: .info, isJSON: false)
        addExport("Info as JSON...", scope: .info, isJSON: true)
        addExport("Fonts as Markdown...", scope: .fonts, isJSON: false)
        addExport("Fonts as JSON...", scope: .fonts, isJSON: true)
        addExport("XMP as Markdown...", scope: .xmp, isJSON: false)
        addExport("XMP as JSON...", scope: .xmp, isJSON: true)
        addExport("Bookmarks as Markdown...", scope: .bookmarks, isJSON: false)
        addExport("Bookmarks as JSON...", scope: .bookmarks, isJSON: true)
        addExport("Annotations as Markdown...", scope: .annotations, isJSON: false)
        addExport("Annotations as JSON...", scope: .annotations, isJSON: true)

        fileMenu.addItem(exportItem)

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Print PDF file...", action: #selector(AppDelegate.printDocument(_:)), keyEquivalent: "p")

        // --- 3. Edit メニュー (Cmd + C 用) ---
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Copy", action: #selector(PDFView.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(NSMenuItem.separator())

        // Find サブメニュー (Preview.app と同じ構成・同じキー)
        let findItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Find")
        findItem.submenu = findMenu

        findMenu.addItem(withTitle: "Find...",
                         action: #selector(AppDelegate.toggleSearchBar(_:)),
                         keyEquivalent: "f")
        findMenu.addItem(withTitle: "Find Next",
                         action: #selector(AppDelegate.findNextAction(_:)),
                         keyEquivalent: "g")
        // 大文字の "G" は Shift + Cmd + G として扱われる
        findMenu.addItem(withTitle: "Find Previous",
                         action: #selector(AppDelegate.findPreviousAction(_:)),
                         keyEquivalent: "G")
        findMenu.addItem(NSMenuItem.separator())
        findMenu.addItem(withTitle: "Use Selection for Find",
                         action: #selector(AppDelegate.useSelectionForFindAction(_:)),
                         keyEquivalent: "e")

        editMenu.addItem(findItem)

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
        let singlePageItem = NSMenuItem(title: "Single Page", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "1")
        let singlePageContinuousItem = NSMenuItem(title: "Single Page Continuous", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "1")
        singlePageContinuousItem.keyEquivalentModifierMask = [.command, .shift]
        let twoPagesItem = NSMenuItem(title: "Two Pages", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "2")
        let twoPagesContinuousItem = NSMenuItem(title: "Two Pages Continuous", action: #selector(AppDelegate.changeDisplayMode(_:)), keyEquivalent: "2")
        twoPagesContinuousItem.keyEquivalentModifierMask = [.command, .shift]

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

        // ページの配色 (アクセシビリティ)
        let pageColorItem = NSMenuItem(title: "Page Color", action: nil, keyEquivalent: "")
        let pageColorMenu = NSMenu(title: "Page Color")
        for (index, group) in PageColorMode.menuGroups.enumerated() {
            if index > 0 {
                pageColorMenu.addItem(NSMenuItem.separator())
            }
            for mode in group {
                let item = NSMenuItem(title: mode.menuTitle,
                                      action: #selector(AppDelegate.changePageColorMode(_:)),
                                      keyEquivalent: "")
                item.tag = mode.rawValue
                pageColorMenu.addItem(item)
            }
        }
        pageColorItem.submenu = pageColorMenu
        viewMenu.addItem(pageColorItem)

        viewMenu.addItem(NSMenuItem.separator())

        // サイドバー系
        let pdfInfoItem = NSMenuItem(title: "PDF Info", action: #selector(AppDelegate.toggleInfoSidebar(_:)), keyEquivalent: "i")
        let pdfBookmarksItem = NSMenuItem(title: "PDF Bookmarks", action: #selector(AppDelegate.toggleBookmarksSidebar(_:)), keyEquivalent: "b")
        let pdfAnnotationsItem = NSMenuItem(title: "PDF Annotations", action: #selector(AppDelegate.toggleAnnotationsSidebar(_:)), keyEquivalent: "n")
        viewMenu.addItem(pdfInfoItem)
        viewMenu.addItem(pdfBookmarksItem)
        viewMenu.addItem(pdfAnnotationsItem)

        viewMenu.addItem(NSMenuItem.separator())

        // ページナビゲーション系
        // 1 アクションにつきメニュー項目は 1 つだけにする。項目名が重複すると
        // システム設定の「Appのショートカット」から一意に指定できなくなるため、
        // 別バインドが欲しい場合はそちらで割り当ててもらう
        let nextPageItem = NSMenuItem(title: "Next Page", action: #selector(AppDelegate.nextPageAction(_:)), keyEquivalent: " ")
        nextPageItem.keyEquivalentModifierMask = []

        let prevPageItem = NSMenuItem(title: "Previous Page", action: #selector(AppDelegate.previousPageAction(_:)), keyEquivalent: " ")
        prevPageItem.keyEquivalentModifierMask = [.shift]

        viewMenu.addItem(nextPageItem)
        viewMenu.addItem(prevPageItem)

        viewMenu.addItem(NSMenuItem.separator())

        // ナビゲーション履歴 (Preview.app と同じ Cmd + [ / Cmd + ])
        // 別バインドが欲しい場合はシステム設定の「Appのショートカット」で
        // この項目名に割り当ててもらう。項目名が一意である必要があるため、
        // ここでは意図的にエイリアスを増やしていない
        let backItem = NSMenuItem(title: "Back", action: #selector(AppDelegate.goBackAction(_:)), keyEquivalent: "[")
        let forwardItem = NSMenuItem(title: "Forward", action: #selector(AppDelegate.goForwardAction(_:)), keyEquivalent: "]")

        viewMenu.addItem(backItem)
        viewMenu.addItem(forwardItem)

        // --- 5. SyncTeX メニュー ---
        let syncTexMenu = NSMenu(title: "SyncTeX")
        let syncTexMenuItem = NSMenuItem()
        syncTexMenuItem.submenu = syncTexMenu

        let emacsItem = NSMenuItem(title: "Emacs", action: #selector(AppDelegate.changeSyncTexEditor(_:)), keyEquivalent: "")
        let vscodeItem = NSMenuItem(title: "Visual Studio Code", action: #selector(AppDelegate.changeSyncTexEditor(_:)), keyEquivalent: "")
        let vimtexItem = NSMenuItem(title: "Vim/Neovim (VimTeX)", action: #selector(AppDelegate.changeSyncTexEditor(_:)), keyEquivalent: "")
        let customItem = NSMenuItem(title: "Custom", action: #selector(AppDelegate.changeSyncTexEditor(_:)), keyEquivalent: "")

        syncTexMenu.addItem(emacsItem)
        syncTexMenu.addItem(vscodeItem)
        syncTexMenu.addItem(vimtexItem)
        syncTexMenu.addItem(NSMenuItem.separator())
        syncTexMenu.addItem(customItem)

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(editMenuItem)
        mainMenu.addItem(viewMenuItem)
        mainMenu.addItem(syncTexMenuItem)

        app.mainMenu = mainMenu
        app.setActivationPolicy(.regular)
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var window: NSWindow?

    // Sparkle updater controller.
    // Pass `updaterDelegate: self` here in future if dynamic feed URL switching
    // (e.g. stable/pro channel toggle based on license) becomes necessary.
    let updaterController: SPUStandardUpdaterController

    override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var container: NSView!
    var pdfViewA: GalleyPDFView!
    var pdfViewB: GalleyPDFView!
    var isShowingA = true
    var sidebarController: SidebarController?

    var activePDFView: GalleyPDFView { isShowingA ? pdfViewA : pdfViewB }
    var hiddenPDFView: GalleyPDFView { isShowingA ? pdfViewB : pdfViewA }

    var timer: Timer?
    var lastUpdate: Date?
    var fileURL: URL?
    var reloadWorkItem: DispatchWorkItem?
    var swapWorkItem: DispatchWorkItem?
    var loadGeneration: Int = 0

    // `open -g "galleypdf://...?background=1"` で起動された場合に、
    // 起動完了時の強制アクティベーションを抑止するためのフラグ。
    var launchedInBackground = false

    // --- 検索バー用プロパティ ---
    var searchBarContainer: NSView?
    var searchBarTopConstraint: NSLayoutConstraint?
    var searchField: NSSearchField?
    var searchMatchCountLabel: NSTextField?
    var searchRegexCheckbox: NSButton?
    var searchMatchCaseCheckbox: NSButton?
    var searchBarVisible: Bool = false
    var searchResults: [PDFSelection] = []
    var searchCurrentIndex: Int = 0

    // ==========================================
    // メニューのチェックマーク状態の管理 (View & SyncTeX)
    // ==========================================
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(changeSyncTexEditor(_:)) {
            return self.validateSyncTexMenuItem(menuItem)
        }

        if menuItem.action == #selector(toggleInfoSidebar(_:)) ||
           menuItem.action == #selector(toggleBookmarksSidebar(_:)) ||
           menuItem.action == #selector(toggleAnnotationsSidebar(_:)) {
            return self.validateSidebarMenuItem(menuItem)
        }

        if menuItem.action == #selector(exportSidebarContent(_:)) {
            return self.validateExportMenuItem(menuItem)
        }

        if menuItem.action == #selector(changePageColorMode(_:)) {
            return self.validatePageColorMenuItem(menuItem)
        }

        // ウィンドウ構築前にも validate が走りうるので optional で受ける
        let viewForValidation: GalleyPDFView? = isShowingA ? pdfViewA : pdfViewB

        // ナビゲーション履歴は行き先がある時だけ有効化
        if menuItem.action == #selector(goBackAction(_:)) {
            return viewForValidation?.canGoBack ?? false
        }
        if menuItem.action == #selector(goForwardAction(_:)) {
            return viewForValidation?.canGoForward ?? false
        }

        // 検索語が無ければ Find Next / Previous は無効
        if menuItem.action == #selector(findNextAction(_:)) ||
           menuItem.action == #selector(findPreviousAction(_:)) {
            return !(self.searchField?.stringValue.isEmpty ?? true)
        }

        // 選択テキストが無ければ Use Selection for Find は無効
        if menuItem.action == #selector(useSelectionForFindAction(_:)) {
            let selected = viewForValidation?.currentSelection?.string ?? ""
            return !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

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

    func applicationWillFinishLaunching(_ notification: Notification) {
        self.setupForwardSearch()

        // Register URL handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "galleypdf" else { return }

        let host = url.host // reload, forward など
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // パラメータを辞書形式に変換
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }

        // background=1 は URL を配送した `open -g` と対になる指定。
        // 起動そのものがこの URL で誘発された場合に備え、非同期ブロックの外で立てる。
        let background = ["1", "true", "yes"].contains(params["background"]?.lowercased() ?? "")
        if background {
            self.launchedInBackground = true
        }

        DispatchQueue.main.async {
            switch host {
            case "reload":
                // 外部から強制リロード (例: open "galleypdf://reload")
                self.reloadPDF()

            case "open":
                // 外部から PDF を開く
                // 例: open "galleypdf://open?pdfpath=/path/to/main.pdf&page=3"
                guard let pdfPath = params["pdfpath"], !pdfPath.isEmpty else { break }
                self.loadPDF(url: URL(fileURLWithPath: pdfPath).absoluteURL, activate: !background)
                if let pageStr = params["page"], let page = Int(pageStr) {
                    self.goToPage(page)
                }

            case "forward":
                // 外部からの Forward Search 実行
                // 例: open "galleypdf://forward?line=123&column=45&pdfpath=/path/to/main.pdf&srcpath=/path/to/source.tex"
                if let lineStr = params["line"], let line = Int32(lineStr) {
                    let pdfPath = params["pdfpath"]
                    let srcPath = params["srcpath"]

                    var column: Int32? = nil
                    if let colStr = params["column"], let col = Int32(colStr) {
                        column = col
                    }

                    self.processForwardSearch(line: line, column: column,
                                              pdfPath: pdfPath, srcPath: srcPath,
                                              background: background)
                }

            default:
                break
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        pdfViewA = GalleyPDFView()
        pdfViewB = GalleyPDFView()

        let savedModeInt = UserDefaults.standard.integer(forKey: "displayMode")
        let savedMode = PDFDisplayMode(rawValue: savedModeInt) ?? .singlePageContinuous
        let savedBookMode = UserDefaults.standard.bool(forKey: "displaysAsBook")
        let savedRTL = UserDefaults.standard.bool(forKey: "displaysRTL")

        for view in [pdfViewA, pdfViewB] {
            view!.autoScales = true
            view!.displayMode = savedMode
            view!.displaysAsBook = savedBookMode
            view!.displaysRTL = savedRTL
            view!.backgroundColor = NSColor.windowBackgroundColor
        }

        // `.normal` のときは何も呼ばれない (レンダリング経路を素のままに保つ)
        self.setupPageColorMode()

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

        let sidebar = SidebarController(mainContainer: container)
        sidebar.onNavigateToDestination = { [weak self] dest in
            self?.activePDFView.go(to: dest)
        }
        self.sidebarController = sidebar

        let window = NSWindow(
            contentRect: container.bounds,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.contentViewController = sidebar
        // Persist window frame (size + position) across launches.
        if !window.setFrameAutosaveName("GalleyMainWindow") {
            window.center()
        }
        self.window = window

        if let url = self.fileURL {
            loadPDF(url: url)
        } else if CommandLine.arguments.count > 1 {
            loadPDF(url: URL(fileURLWithPath: CommandLine.arguments[1]).absoluteURL)
        } else {
            window.title = "Galley"
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.fileURL == nil { self.openDocument(nil) }
            }
        }
        if self.launchedInBackground {
            // `open -g` で起動したときはフォアグラウンドを奪わずに窓だけ見せる
            window.orderFrontRegardless()
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        sidebarController?.prepareForTermination()
    }
}
