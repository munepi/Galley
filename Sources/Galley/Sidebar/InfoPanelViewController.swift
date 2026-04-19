// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

final class InfoPanelViewController: NSViewController {

    private var info: PDFDocumentInfo = .empty
    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    private var documentView: FlippedView!

    private var keyColumnWidth: CGFloat = 140
    private let keyColumnMin: CGFloat = 80
    private let keyColumnMax: CGFloat = 220

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 600))
        self.view = root

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        contentStack.spacing = 14
        contentStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
        ])

        scrollView.documentView = documentView
        // documentView の幅は clipView に追従、高さはコンテンツに従う
        if let clipView = scrollView.contentView as NSClipView? {
            NSLayoutConstraint.activate([
                documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
                documentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
                documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            ])
        }
    }

    func reload(document: PDFDocument?, url: URL?) {
        self.info = PDFDocumentInfoBuilder.build(document: document, url: url)
        rebuildViews()
        Log.pdfinfo.info("reload sections=\(self.info.sections.count)")
    }

    private func rebuildViews() {
        // 既存の子View全削除
        for v in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        guard !info.sections.isEmpty else {
            let label = NSTextField(labelWithString: "(no document)")
            label.textColor = .secondaryLabelColor
            contentStack.addArrangedSubview(label)
            return
        }
        keyColumnWidth = computeKeyColumnWidth()
        for section in info.sections {
            contentStack.addArrangedSubview(makeSectionView(section))
        }
    }

    private func computeKeyColumnWidth() -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var maxWidth: CGFloat = 0
        for section in info.sections {
            for row in section.rows {
                let key: String
                switch row {
                case .keyValue(let k, _): key = k
                case .longText(let l, _): key = l
                }
                let width = (key as NSString).size(withAttributes: attrs).width
                if width > maxWidth { maxWidth = width }
            }
        }
        return min(max(ceil(maxWidth) + 4, keyColumnMin), keyColumnMax)
    }

    private func makeSectionView(_ section: InfoSection) -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 4
        sectionStack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: section.title)
        header.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        header.textColor = .secondaryLabelColor
        sectionStack.addArrangedSubview(header)

        for row in section.rows {
            sectionStack.addArrangedSubview(makeRowView(row))
        }

        // セクションは親stack幅いっぱいに広げたい
        sectionStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return sectionStack
    }

    private func makeRowView(_ row: InfoRow) -> NSView {
        switch row {
        case .keyValue(let key, let value):
            return makeKeyValueRow(key: key, value: value, monospaceValue: false)
        case .longText(let label, let value):
            return makeKeyValueRow(key: label, value: value, monospaceValue: true)
        }
    }

    private func makeKeyValueRow(key: String, value: String, monospaceValue: Bool) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.distribution = .fill
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let keyLabel = NSTextField(labelWithString: key)
        keyLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        keyLabel.textColor = .secondaryLabelColor
        keyLabel.lineBreakMode = .byTruncatingTail
        keyLabel.maximumNumberOfLines = 1
        keyLabel.alignment = .right
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.widthAnchor.constraint(equalToConstant: keyColumnWidth).isActive = true
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueField = WrappingLabel(wrappingLabelWithString: value)
        valueField.isSelectable = true
        valueField.isEditable = false
        valueField.isBordered = false
        valueField.drawsBackground = false
        valueField.allowsEditingTextAttributes = false
        valueField.lineBreakMode = .byWordWrapping
        valueField.maximumNumberOfLines = 0
        if monospaceValue {
            valueField.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        } else {
            valueField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        valueField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueField.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(keyLabel)
        row.addArrangedSubview(valueField)

        row.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }
}

/// 上原点（top-left）のスクロールビュー用documentView
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// リサイズ時に preferredMaxLayoutWidth を追従させて無限ループを防ぐラベル
private final class WrappingLabel: NSTextField {
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if abs(preferredMaxLayoutWidth - newSize.width) > 0.5 {
            preferredMaxLayoutWidth = newSize.width
            invalidateIntrinsicContentSize()
        }
    }
}
