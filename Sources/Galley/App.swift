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
            "debugMode": false,
            "syncTexEditor": "emacs",
            "emacsclientPath": "",
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
        appMenu.addItem(withTitle: "Quit Galley", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

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
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Find...", action: #selector(AppDelegate.toggleSearchBar(_:)), keyEquivalent: "f")

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

        // --- 5. SyncTeX メニュー ---
        let syncTexMenu = NSMenu(title: "SyncTeX")
        let syncTexMenuItem = NSMenuItem()
        syncTexMenuItem.submenu = syncTexMenu

        let emacsItem = NSMenuItem(title: "Emacs", action: #selector(AppDelegate.changeSyncTexEditor(_:)), keyEquivalent: "")
        let vscodeItem = NSMenuItem(title: "Visual Studio Code", action: #selector(AppDelegate.changeSyncTexEditor(_:)), keyEquivalent: "")
        let customItem = NSMenuItem(title: "Custom", action: #selector(AppDelegate.changeSyncTexEditor(_:)), keyEquivalent: "")

        syncTexMenu.addItem(emacsItem)
        syncTexMenu.addItem(vscodeItem)
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

    var container: NSView!
    var pdfViewA: GalleyPDFView!
    var pdfViewB: GalleyPDFView!
    var isShowingA = true

    var activePDFView: GalleyPDFView { isShowingA ? pdfViewA : pdfViewB }
    var hiddenPDFView: GalleyPDFView { isShowingA ? pdfViewB : pdfViewA }

    var timer: Timer?
    var lastUpdate: Date?
    var fileURL: URL?
    var reloadWorkItem: DispatchWorkItem?
    var swapWorkItem: DispatchWorkItem?
    var loadGeneration: Int = 0

    // --- 検索バー用プロパティ ---
    var searchBarContainer: NSView?
    var searchBarTopConstraint: NSLayoutConstraint?
    var searchField: NSSearchField?
    var searchMatchCountLabel: NSTextField?
    var searchRegexCheckbox: NSButton?
    var searchBarVisible: Bool = false
    var searchResults: [PDFSelection] = []
    var searchCurrentIndex: Int = 0

    var isDebugMode: Bool {
        return UserDefaults.standard.bool(forKey: "debugMode")
    }

    // ==========================================
    // メニューのチェックマーク状態の管理 (View & SyncTeX)
    // ==========================================
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(changeSyncTexEditor(_:)) {
            return self.validateSyncTexMenuItem(menuItem)
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

        DispatchQueue.main.async {
            switch host {
            case "reload":
                // 外部から強制リロード (例: open "galleypdf://reload")
                self.reloadPDF()

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

                    self.processForwardSearch(line: line, column: column, pdfPath: pdfPath, srcPath: srcPath)
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
            window.title = "Galley"
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
