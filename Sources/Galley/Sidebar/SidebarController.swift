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
    private(set) var infoPanel: InfoPanelViewController!

    private static let leftVisibleKey = "sidebar.leftVisible"

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
        splitView.dividerStyle = .thin

        let infoVC = InfoPanelViewController()
        self.infoPanel = infoVC

        let leftItem = NSSplitViewItem(sidebarWithViewController: infoVC)
        leftItem.canCollapse = true
        leftItem.minimumThickness = 180
        leftItem.maximumThickness = 500
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

        Log.sidebar.info("SidebarController loaded leftCollapsed=\(leftItem.isCollapsed)")
    }

    func toggleLeft() {
        let newCollapsed = !leftItem.isCollapsed
        leftItem.animator().isCollapsed = newCollapsed
        UserDefaults.standard.set(!newCollapsed, forKey: Self.leftVisibleKey)
        Log.sidebar.info("toggleLeft collapsed=\(newCollapsed)")
    }

    var isLeftVisible: Bool {
        !leftItem.isCollapsed
    }

    func notifyDocumentChanged(_ document: PDFDocument?, url: URL?) {
        infoPanel?.reload(document: document, url: url)
    }

    // ドラッグで左ペインを最小幅より狭くできないように制約（auto-collapse 防止）
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
