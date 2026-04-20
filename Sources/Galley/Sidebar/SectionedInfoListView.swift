// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit

/// PDFDocumentInfo のセクション列をスクロール可能にレンダリングする共有ビュー。
/// InfoBasicViewController / XMPSubPanelViewController などが利用する。
final class SectionedInfoListView: NSView {

    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()
    private let documentView = FlippedView()

    private var keyColumnWidth: CGFloat = 100
    private let keyColumnMin: CGFloat = 60
    private let keyColumnMax: CGFloat = 100

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        documentView.translatesAutoresizingMaskIntoConstraints = false

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
        if let clipView = scrollView.contentView as NSClipView? {
            NSLayoutConstraint.activate([
                documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
                documentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
                documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            ])
        }
    }

    func setInfo(_ info: PDFDocumentInfo, emptyMessage: String = "(no document)") {
        for v in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        guard !info.sections.isEmpty else {
            let label = NSTextField(labelWithString: emptyMessage)
            label.textColor = .secondaryLabelColor
            contentStack.addArrangedSubview(label)
            return
        }
        keyColumnWidth = computeKeyColumnWidth(for: info)
        for section in info.sections {
            let sv = makeSectionView(section)
            contentStack.addArrangedSubview(sv)
            sv.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: contentStack.edgeInsets.left).isActive = true
            sv.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -contentStack.edgeInsets.right).isActive = true
        }
    }

    private func computeKeyColumnWidth(for info: PDFDocumentInfo) -> CGFloat {
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
            let rv = makeRowView(row)
            sectionStack.addArrangedSubview(rv)
            rv.leadingAnchor.constraint(equalTo: sectionStack.leadingAnchor).isActive = true
            rv.trailingAnchor.constraint(equalTo: sectionStack.trailingAnchor).isActive = true
        }

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
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let keyLabel = WrappingLabel(wrappingLabelWithString: key)
        keyLabel.isEditable = false
        keyLabel.isSelectable = false
        keyLabel.isBordered = false
        keyLabel.drawsBackground = false
        keyLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        keyLabel.textColor = .secondaryLabelColor
        keyLabel.lineBreakMode = .byWordWrapping
        keyLabel.maximumNumberOfLines = 0
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

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
