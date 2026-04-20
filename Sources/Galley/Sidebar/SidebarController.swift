// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

final class SidebarController: NSSplitViewController {

    private let mainContainer: NSView
    private(set) var leftItem: NSSplitViewItem!
    private(set) var mainItem: NSSplitViewItem!

    private var rootVC: SidebarRootViewController!
    private(set) var infoPanel: InfoPanelViewController!
    private(set) var bookmarksPanel: BookmarksPanelViewController!
    private(set) var annotationsPanel: AnnotationsPanelViewController!

    private var currentPanelKind: SidebarPanelKind = .info

    private var currentDocument: PDFDocument?
    private var currentURL: URL?

    /// 栞や注釈パネルからのジャンプ要求を受けるコールバック。AppDelegate が PDFView.go(to:) に流す
    var onNavigateToDestination: ((PDFDestination) -> Void)?

    private static let leftVisibleKey = "sidebar.leftVisible"
    private static let panelKindKey = "sidebar.panelKind"

    init(mainContainer: NSView) {
        self.mainContainer = mainContainer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.autosaveName = "galley.sidebar.splitview"
        splitView.dividerStyle = .paneSplitter

        rootVC = SidebarRootViewController()
        infoPanel = InfoPanelViewController()
        bookmarksPanel = BookmarksPanelViewController()
        annotationsPanel = AnnotationsPanelViewController()

        bookmarksPanel.onNavigate = { [weak self] dest in
            self?.onNavigateToDestination?(dest)
        }
        annotationsPanel.onNavigate = { [weak self] dest in
            self?.onNavigateToDestination?(dest)
        }

        // 保存された初期パネル
        let savedRaw = UserDefaults.standard.string(forKey: Self.panelKindKey) ?? SidebarPanelKind.info.rawValue
        currentPanelKind = SidebarPanelKind(rawValue: savedRaw) ?? .info
        rootVC.loadViewIfNeeded()
        rootVC.showPanel(panelVC(for: currentPanelKind))

        let leftItem = NSSplitViewItem(sidebarWithViewController: rootVC)
        leftItem.canCollapse = true
        leftItem.minimumThickness = 300
        leftItem.maximumThickness = 600
        leftItem.isCollapsed = !UserDefaults.standard.bool(forKey: Self.leftVisibleKey)
        self.leftItem = leftItem

        let mainVC = NSViewController()
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(mainContainer)
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: wrapper.topAnchor),
            mainContainer.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            mainContainer.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            mainContainer.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])
        mainVC.view = wrapper
        let mainItem = NSSplitViewItem(viewController: mainVC)
        mainItem.canCollapse = false
        mainItem.minimumThickness = 300
        self.mainItem = mainItem

        addSplitViewItem(leftItem)
        addSplitViewItem(mainItem)

        Log.sidebar.info("SidebarController loaded leftCollapsed=\(leftItem.isCollapsed) panel=\(self.currentPanelKind.rawValue)")
    }

    private func panelVC(for kind: SidebarPanelKind) -> SidebarPanelViewController {
        switch kind {
        case .info: return infoPanel
        case .bookmarks: return bookmarksPanel
        case .annotations: return annotationsPanel
        }
    }

    var isLeftVisible: Bool {
        !leftItem.isCollapsed
    }

    /// ⌘I/⌘B/⌘N の統一エントリポイント。スマートトグル:
    /// - サイドバー閉じてる → パネル切替して開く
    /// - 開いてて違うパネル → パネル切替（開いたまま）
    /// - 開いてて同じパネル → 閉じる
    func activatePanel(_ kind: SidebarPanelKind) {
        if leftItem.isCollapsed {
            switchPanel(to: kind)
            leftItem.animator().isCollapsed = false
            UserDefaults.standard.set(true, forKey: Self.leftVisibleKey)
        } else if currentPanelKind == kind {
            leftItem.animator().isCollapsed = true
            UserDefaults.standard.set(false, forKey: Self.leftVisibleKey)
        } else {
            switchPanel(to: kind)
        }
        Log.sidebar.info("activatePanel kind=\(kind.rawValue) collapsed=\(self.leftItem.isCollapsed)")
    }

    private func switchPanel(to kind: SidebarPanelKind) {
        currentPanelKind = kind
        UserDefaults.standard.set(kind.rawValue, forKey: Self.panelKindKey)
        let vc = panelVC(for: kind)
        rootVC.showPanel(vc)
        vc.reload(document: currentDocument, url: currentURL)
    }

    /// 現在表示中のパネル種別
    var activePanelKind: SidebarPanelKind { currentPanelKind }

    func notifyDocumentChanged(_ document: PDFDocument?, url: URL?) {
        currentDocument = document
        currentURL = url
        rootVC.reloadCurrent(document: document, url: url)
    }

    // MARK: - NSSplitView delegate

    override func splitView(_ splitView: NSSplitView,
                            canCollapseSubview subview: NSView) -> Bool {
        return false
    }

    override func splitView(_ splitView: NSSplitView,
                            constrainSplitPosition proposedPosition: CGFloat,
                            ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0, !leftItem.isCollapsed {
            return max(proposedPosition, leftItem.minimumThickness)
        }
        return proposedPosition
    }

    override func splitView(_ splitView: NSSplitView,
                            shouldCollapseSubview subview: NSView,
                            forDoubleClickOnDividerAt dividerIndex: Int) -> Bool {
        return false
    }
}
