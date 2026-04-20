// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// Info パネル: 上部の NSSegmentedControl で Info / Fonts / XMP を切り替えるコンテナ
final class InfoPanelViewController: NSViewController, SidebarPanelViewController, ExportableContent {

    enum SubTab: Int, CaseIterable {
        case info = 0
        case fonts = 1
        case xmp = 2

        var title: String {
            switch self {
            case .info: return "Info"
            case .fonts: return "Fonts"
            case .xmp: return "XMP"
            }
        }
    }

    private var segmented: NSSegmentedControl!
    private var containerView: NSView!

    private(set) var infoVC: InfoBasicViewController!
    private(set) var fontsVC: FontsSubPanelViewController!
    private(set) var xmpVC: XMPSubPanelViewController!

    private var currentTab: SubTab = .info

    private var currentDocument: PDFDocument?
    private var currentURL: URL?

    private static let subTabKey = "sidebar.info.subTab"

    override func loadView() {
        let root = NSView()
        self.view = root

        segmented = NSSegmentedControl(labels: SubTab.allCases.map { $0.title },
                                       trackingMode: .selectOne,
                                       target: self,
                                       action: #selector(segmentedChanged(_:)))
        segmented.segmentStyle = .automatic
        segmented.translatesAutoresizingMaskIntoConstraints = false

        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(segmented)
        root.addSubview(containerView)
        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmented.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            segmented.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),

            containerView.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        infoVC = InfoBasicViewController()
        fontsVC = FontsSubPanelViewController()
        xmpVC = XMPSubPanelViewController()

        // 非表示サブタブにも reload/Export を通すため事前に view をロード
        _ = infoVC.view
        _ = fontsVC.view
        _ = xmpVC.view

        // 保存されたサブタブを復元
        let savedRaw = UserDefaults.standard.integer(forKey: Self.subTabKey)
        let saved = SubTab(rawValue: savedRaw) ?? .info
        currentTab = saved
        segmented.selectedSegment = saved.rawValue

        swapToCurrentSubPanel()
    }

    @objc private func segmentedChanged(_ sender: NSSegmentedControl) {
        guard let tab = SubTab(rawValue: sender.selectedSegment) else { return }
        currentTab = tab
        UserDefaults.standard.set(tab.rawValue, forKey: Self.subTabKey)
        swapToCurrentSubPanel()
    }

    private func swapToCurrentSubPanel() {
        for child in children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        let sub: NSViewController
        switch currentTab {
        case .info: sub = infoVC
        case .fonts: sub = fontsVC
        case .xmp: sub = xmpVC
        }
        addChild(sub)
        let sv = sub.view
        sv.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: containerView.topAnchor),
            sv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        // 現在の document を反映
        reloadCurrentSub()
    }

    private func reloadCurrentSub() {
        switch currentTab {
        case .info: infoVC.reload(document: currentDocument, url: currentURL)
        case .fonts: fontsVC.reload(document: currentDocument, url: currentURL)
        case .xmp: xmpVC.reload(document: currentDocument, url: currentURL)
        }
    }

    // MARK: - SidebarPanelViewController

    func reload(document: PDFDocument?, url: URL?) {
        self.currentDocument = document
        self.currentURL = url
        // 全サブVCを reload して、見えていない XMP/Fonts の Export も機能するようにする
        infoVC.reload(document: document, url: url)
        fontsVC.reload(document: document, url: url)
        xmpVC.reload(document: document, url: url)
    }

    // MARK: - ExportableContent: 現在のサブタブに委譲

    private var currentExportable: ExportableContent? {
        switch currentTab {
        case .info: return infoVC
        case .fonts: return fontsVC
        case .xmp: return xmpVC
        }
    }

    func exportedMarkdown() -> String? {
        currentExportable?.exportedMarkdown()
    }

    func exportedJSON() -> String? {
        currentExportable?.exportedJSON()
    }
}
