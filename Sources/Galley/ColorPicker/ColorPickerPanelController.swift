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

import AppKit
import PDFKit

// ==========================================
// Color Picker パネル (Digital Color Meter 風のフローティングパネル)
//
//   ┌──────────┐  ■  C:   0%
//   │ 拡大鏡   │     M: 100%
//   │   [+]    │     Y: 100%
//   └──────────┘     K:   0%
//                    ≈ sRGB #ED1C24
//   DeviceCMYK · Text "あ"                 [Copy]
//
// 値の計算は GalleyPDFView+ColorPicker が行い、ここは表示に徹する。
// ==========================================
final class ColorPickerPanelController: NSWindowController, NSWindowDelegate {

    static let magnifierPixels = 168
    /// 拡大鏡が映すページ上の範囲 (pt 四方)
    static let magnifierExtent: CGFloat = 24

    var onClose: (() -> Void)?

    private(set) var isLocked = false {
        didSet { updateTitle() }
    }

    private let magnifierView = NSImageView()
    private let swatchView = NSView()
    private let valuesLabel = NSTextField(labelWithString: "")
    private let srgbLabel = NSTextField(labelWithString: "")
    private let spaceLabel = NSTextField(labelWithString: "")
    private let notesLabel = NSTextField(labelWithString: "")
    private let positionLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)

    /// Copy ボタンで書き出すテキスト
    private var copyText: String = ""

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 236),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Color Picker"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.setFrameAutosaveName("ColorPickerPanel")

        super.init(window: panel)
        panel.delegate = self
        buildContent(in: panel)
        showNoPage()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    private func buildContent(in panel: NSPanel) {
        guard let content = panel.contentView else { return }

        let px = ColorPickerPanelController.magnifierPixels
        magnifierView.imageScaling = .scaleNone
        magnifierView.wantsLayer = true
        magnifierView.layer?.borderWidth = 1
        magnifierView.layer?.borderColor = NSColor.separatorColor.cgColor
        magnifierView.layer?.backgroundColor = NSColor.white.cgColor
        magnifierView.translatesAutoresizingMaskIntoConstraints = false
        magnifierView.widthAnchor.constraint(equalToConstant: CGFloat(px)).isActive = true
        magnifierView.heightAnchor.constraint(equalToConstant: CGFloat(px)).isActive = true

        swatchView.wantsLayer = true
        swatchView.layer?.borderWidth = 1
        swatchView.layer?.borderColor = NSColor.separatorColor.cgColor
        swatchView.layer?.cornerRadius = 4
        swatchView.translatesAutoresizingMaskIntoConstraints = false
        swatchView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        swatchView.heightAnchor.constraint(equalToConstant: 48).isActive = true

        valuesLabel.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        valuesLabel.maximumNumberOfLines = 0
        valuesLabel.lineBreakMode = .byClipping
        valuesLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valuesLabel.translatesAutoresizingMaskIntoConstraints = false
        valuesLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        srgbLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        srgbLabel.textColor = .secondaryLabelColor

        spaceLabel.font = .systemFont(ofSize: 12, weight: .medium)
        spaceLabel.lineBreakMode = .byTruncatingTail
        spaceLabel.maximumNumberOfLines = 1

        notesLabel.font = .systemFont(ofSize: 11)
        notesLabel.textColor = .secondaryLabelColor
        notesLabel.lineBreakMode = .byTruncatingTail
        notesLabel.maximumNumberOfLines = 2

        positionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        positionLabel.textColor = .secondaryLabelColor

        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .small
        copyButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        copyButton.target = self
        copyButton.action = #selector(copyValues(_:))

        let swatchRow = NSStackView(views: [swatchView, valuesLabel])
        swatchRow.orientation = .horizontal
        swatchRow.alignment = .top
        swatchRow.spacing = 10

        let rightColumn = NSStackView(views: [swatchRow, srgbLabel, spaceLabel, notesLabel])
        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 6

        let topRow = NSStackView(views: [magnifierView, rightColumn])
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.spacing = 12

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bottomRow = NSStackView(views: [positionLabel, spacer, copyButton])
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .centerY
        bottomRow.spacing = 8

        let root = NSStackView(views: [topRow, bottomRow])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            bottomRow.widthAnchor.constraint(equalTo: root.widthAnchor),
            topRow.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])
    }

    // MARK: - Lock

    func setLocked(_ locked: Bool) {
        isLocked = locked
        Log.colorPicker.debug("panel setLocked(\(locked))")
    }

    private func updateTitle() {
        window?.title = isLocked ? "Color Picker 🔒 Locked" : "Color Picker"
    }

    // MARK: - Updates

    func showNoPage() {
        magnifierView.image = nil
        swatchView.layer?.backgroundColor = NSColor.clear.cgColor
        valuesLabel.stringValue = "—"
        srgbLabel.stringValue = ""
        spaceLabel.stringValue = "No page under the cursor"
        notesLabel.stringValue = ""
        positionLabel.stringValue = ""
        copyText = ""
        copyButton.isEnabled = false
    }

    func setMagnifier(_ image: NSImage?) {
        magnifierView.image = image
    }

    /// ヒット結果を表示する。`pageIndex` は 0 始まり。
    func update(hit: PDFColorHit, pageLabel: String?, pageIndex: Int?, point: CGPoint?) {
        // --- スウォッチ ---
        if let c = hit.swatchColor {
            swatchView.layer?.backgroundColor = c.cgColor
        } else {
            swatchView.layer?.backgroundColor = NSColor.clear.cgColor
        }

        // --- 成分値 (縦並び) ---
        let displayColor: PDFPaintColor? = hit.sample?.color ?? hit.color
        var valueLines: [String] = []
        if let c = displayColor {
            let pairs = c.componentPairs
            let labelWidth = pairs.map { $0.0.count }.max() ?? 1
            for (label, value) in pairs {
                let padded = label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
                valueLines.append("\(padded): \(value)")
            }
            if pairs.isEmpty, let pn = c.patternName {
                valueLines.append("/\(pn)")
            }
        } else if hit.needsSampling {
            valueLines.append("(sampling…)")
        } else {
            valueLines.append("—")
        }
        valuesLabel.stringValue = valueLines.joined(separator: "\n")

        // --- ≈ sRGB / 0–255 ---
        var srgbParts: [String] = []
        if let c = displayColor, let r = c.formatted255 {
            srgbParts.append(r)
        }
        if let c = hit.swatchColor {
            srgbParts.append("≈ sRGB \(PDFPaintColor.hexString(c))")
        }
        srgbLabel.stringValue = srgbParts.joined(separator: "   ")

        // --- 色空間 · 対象 ---
        var spaceParts: [String] = []
        if hit.sample != nil, let s = hit.sample {
            spaceParts.append("\(s.color.space.displayName) (sampled)")
        } else {
            spaceParts.append(hit.spaceDescription)
        }
        spaceParts.append(hit.kindDescription)
        if hit.alpha < 1 {
            spaceParts.append(String(format: "α %.2f", hit.alpha))
        }
        if let bm = hit.blendMode {
            spaceParts.append(bm)
        }
        spaceLabel.stringValue = spaceParts.joined(separator: " · ")

        // --- 補足 ---
        var notes = hit.notes
        if let alt = hit.color?.alternateColor {
            notes.insert("alt \(alt.space.displayName): \(alt.formattedComponents)", at: 0)
        }
        if let sc = hit.strokeColor {
            notes.insert("stroke \(sc.space.displayName): \(sc.formattedComponents)", at: 0)
        }
        notesLabel.stringValue = notes.joined(separator: " · ")

        // --- 位置 ---
        var pos: [String] = []
        if let i = pageIndex {
            if let l = pageLabel, l != "\(i + 1)" {
                pos.append("p. \(l) (#\(i + 1))")
            } else {
                pos.append("p. \(i + 1)")
            }
        }
        if let p = point {
            pos.append(String(format: "(%.1f, %.1f) pt", p.x, p.y))
        }
        positionLabel.stringValue = pos.joined(separator: "  ")

        // --- Copy 用テキスト ---
        var copyLines: [String] = []
        var first = spaceParts[0]
        if let c = displayColor {
            first += "  " + c.formattedComponents
        }
        if let c = hit.swatchColor {
            first += "  (≈ sRGB \(PDFPaintColor.hexString(c)))"
        }
        copyLines.append(first)
        var second = hit.kindDescription
        if !pos.isEmpty { second += " — " + pos.joined(separator: ", ") }
        copyLines.append(second)
        if !notes.isEmpty { copyLines.append(notes.joined(separator: "; ")) }
        copyText = copyLines.joined(separator: "\n")
        copyButton.isEnabled = true
    }

    @objc private func copyValues(_ sender: Any?) {
        guard !copyText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(copyText, forType: .string)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        isLocked = false
        onClose?()
    }
}
