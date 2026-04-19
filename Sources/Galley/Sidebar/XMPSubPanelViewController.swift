// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// Info パネル内「XMP」サブタブ: PDF catalog `/Metadata` stream の生XMLを表示
final class XMPSubPanelViewController: NSViewController {

    private var statusLabel: NSTextField!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!

    override func loadView() {
        let root = NSView()
        self.view = root

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize - 1)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(statusLabel)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 4

        scrollView.documentView = textView

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
    }

    func reload(document: PDFDocument?, url: URL?) {
        guard let doc = document else {
            setState("(no document)", body: "")
            return
        }
        let result = CGPDFMetadataExtractor.extract(from: doc)
        if !result.isPresent {
            setState("No XMP metadata embedded in this PDF.", body: "")
        } else if let xml = result.xml {
            let status = "\(NumberFormatter.localizedString(from: NSNumber(value: result.byteCount), number: .decimal)) bytes"
            setState(status, body: xml)
        } else {
            let status = "XMP stream (\(result.byteCount) bytes, undecodable — likely non-text)"
            setState(status, body: "")
        }
        Log.pdfinfo.info("XMP present=\(result.isPresent) decoded=\(result.xml != nil) bytes=\(result.byteCount)")
    }

    private func setState(_ status: String, body: String) {
        statusLabel.stringValue = status
        textView.string = body
    }
}
