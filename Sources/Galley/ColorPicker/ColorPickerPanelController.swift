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
// Color Picker パネル (Digital Color Meter 風 + Acrobat 出力プレビューの色分解)
//
//   ┌────────┐  ■  C:   0%         Separations · Japan Color 2001 Coated
//   │ 拡大鏡 │     M: 100%         ■ Cyan            0%
//   │        │     Y: 100%         ■ Magenta       100%
//   └────────┘     K:   0%         ■ Yellow        100%
//                  ≈ sRGB #D8232A  ■ Black           0%
//                                  ■ DIC 161s*       0%
//                                  TAC 200%
//   DeviceCMYK · Text "あ"
//   alt … · notes …
//   Display [Native Values ▾]   Simulate [Document: FOGRA39L Coated ▾]
//   p. 1  (123.4, 567.8) pt                      [Copy Text] [Copy PDF]
//
// 値の計算は GalleyPDFView+ColorPicker (ヒット) と PDFColorReadout (変換・分版) が行い、
// ここは最後のヒットを保持して表示に徹する。表示モードやプロファイルが変わったときは
// 同じヒットを再表現する (カーソルがパネル上にあるので mouseMoved は来ない)。
// ==========================================
final class ColorPickerPanelController: NSWindowController, NSWindowDelegate, NSMenuDelegate {

    static let magnifierPixels = 168
    /// 拡大鏡が映すページ上の範囲 (pt 四方)
    static let magnifierExtent: CGFloat = 24
    /// 分版リストに出す特色の上限
    static let maxSpotRows = 8
    /// パネルの内容幅 (固定)。高さだけ内容に合わせる
    static let contentWidth: CGFloat = 640

    var onClose: (() -> Void)?

    private let settings: ColorDisplaySettings

    private(set) var isLocked = false {
        didSet { updateTitle() }
    }

    // --- 左: 拡大鏡 ---
    private let magnifierView = NSImageView()
    // --- 中: スウォッチと値 ---
    private let swatchView = NSView()
    private let valuesLabel = NSTextField(labelWithString: "")
    private let srgbLabel = NSTextField(labelWithString: "")
    // --- 右: 分版 ---
    private let separationsHeader = NSTextField(labelWithString: "")
    private let separationsStack = NSStackView()
    private var separationRows: [SeparationRowView] = []
    private let tacLabel = NSTextField(labelWithString: "")
    // --- 下: 説明、オプション、位置、ボタン ---
    private let spaceLabel = NSTextField(labelWithString: "")
    private let notesLabel = NSTextField(labelWithString: "")
    private let displayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let simulatePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let positionLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "Copy Text", target: nil, action: nil)
    private let copyPDFButton = NSButton(title: "Copy PDF", target: nil, action: nil)

    // --- 最後の読み取り (再表現用) ---
    private var lastHit: PDFColorHit?
    private var lastSpots: [CGPDFPageColorScanner.SpotPlate] = []
    private var lastPageLabel: String?
    private var lastPageIndex: Int?
    private var lastPoint: CGPoint?

    /// Copy Text で書き出すテキスト
    private var copyText: String = ""
    /// Copy PDF で書き出す色 (サンプル値があればそれ)
    private var copyColor: PDFPaintColor? = nil
    private var copyColorIsSampled = false

    /// メニューの Copy Color as Text / PDF を有効にしてよいか
    var canCopyText: Bool { !copyText.isEmpty }
    var canCopyPDF: Bool { copyColor.map { PDFColorSwatchWriter.prepare($0) != nil } ?? false }

    init(settings: ColorDisplaySettings) {
        self.settings = settings
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: ColorPickerPanelController.contentWidth, height: 320),
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
        settings.onChange = { [weak self] in
            self?.settingsDidChange()
        }
        showNoPage()
        fitWindowToContent()
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
        valuesLabel.translatesAutoresizingMaskIntoConstraints = false
        valuesLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        srgbLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        srgbLabel.textColor = .secondaryLabelColor
        srgbLabel.maximumNumberOfLines = 2
        srgbLabel.lineBreakMode = .byWordWrapping
        srgbLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        separationsHeader.font = .systemFont(ofSize: 11, weight: .medium)
        separationsHeader.textColor = .secondaryLabelColor
        separationsHeader.lineBreakMode = .byTruncatingTail
        separationsHeader.maximumNumberOfLines = 1
        separationsHeader.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        separationsStack.orientation = .vertical
        separationsStack.alignment = .leading
        separationsStack.spacing = 2

        tacLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        spaceLabel.font = .systemFont(ofSize: 12, weight: .medium)
        spaceLabel.lineBreakMode = .byTruncatingTail
        spaceLabel.maximumNumberOfLines = 1
        spaceLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        notesLabel.font = .systemFont(ofSize: 11)
        notesLabel.textColor = .secondaryLabelColor
        notesLabel.lineBreakMode = .byTruncatingTail
        notesLabel.maximumNumberOfLines = 2
        notesLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        positionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        positionLabel.textColor = .secondaryLabelColor

        for popup in [displayPopup, simulatePopup] {
            popup.controlSize = .small
            popup.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            popup.focusRingType = .none
            (popup.cell as? NSPopUpButtonCell)?.lineBreakMode = .byTruncatingMiddle
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.target = self
        }
        for mode in ColorDisplayMode.allCases {
            displayPopup.addItem(withTitle: mode.title)
            displayPopup.lastItem?.representedObject = mode.rawValue
        }
        displayPopup.action = #selector(displayModeChanged(_:))
        displayPopup.widthAnchor.constraint(lessThanOrEqualToConstant: 170).isActive = true
        simulatePopup.action = #selector(simulationChanged(_:))
        simulatePopup.widthAnchor.constraint(lessThanOrEqualToConstant: 260).isActive = true
        simulatePopup.menu?.delegate = self
        rebuildSimulateMenu()

        for (button, action) in [(copyButton, #selector(copyColorAsText(_:))),
                                 (copyPDFButton, #selector(copyColorAsPDF(_:)))] {
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            button.target = self
            button.action = action
        }
        copyButton.toolTip = "Copy the values as text (⇧⌘C)"
        copyPDFButton.toolTip = "Copy a \(Int(PDFColorSwatchWriter.swatchSize)) pt square filled with this color as vector PDF, color space included (⌥⌘C)"

        // --- 中カラム ---
        let swatchRow = NSStackView(views: [swatchView, valuesLabel])
        swatchRow.orientation = .horizontal
        swatchRow.alignment = .top
        swatchRow.spacing = 10
        let valuesColumn = NSStackView(views: [swatchRow, srgbLabel])
        valuesColumn.orientation = .vertical
        valuesColumn.alignment = .leading
        valuesColumn.spacing = 6
        valuesColumn.translatesAutoresizingMaskIntoConstraints = false
        valuesColumn.widthAnchor.constraint(equalToConstant: 220).isActive = true

        // --- 右カラム ---
        let separationsColumn = NSStackView(views: [separationsHeader, separationsStack, tacLabel])
        separationsColumn.orientation = .vertical
        separationsColumn.alignment = .leading
        separationsColumn.spacing = 4
        separationsColumn.translatesAutoresizingMaskIntoConstraints = false
        separationsColumn.widthAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true
        separationsColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let topRow = NSStackView(views: [magnifierView, valuesColumn, separationsColumn])
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.spacing = 14

        // --- オプション行 ---
        let displayLabel = NSTextField(labelWithString: "Display:")
        let simulateLabel = NSTextField(labelWithString: "Simulate:")
        for l in [displayLabel, simulateLabel] {
            l.font = .systemFont(ofSize: 11)
            l.textColor = .secondaryLabelColor
        }
        let optionsRow = NSStackView(views: [displayLabel, displayPopup, simulateLabel, simulatePopup])
        optionsRow.orientation = .horizontal
        optionsRow.alignment = .centerY
        optionsRow.spacing = 6
        optionsRow.setCustomSpacing(14, after: displayPopup)

        // --- 位置とボタン ---
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bottomRow = NSStackView(views: [positionLabel, spacer, copyButton, copyPDFButton])
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .centerY
        bottomRow.spacing = 8

        let root = NSStackView(views: [topRow, spaceLabel, notesLabel, optionsRow, bottomRow])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 8
        root.setCustomSpacing(4, after: spaceLabel)
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            bottomRow.widthAnchor.constraint(equalTo: root.widthAnchor),
            topRow.widthAnchor.constraint(equalTo: root.widthAnchor),
            spaceLabel.widthAnchor.constraint(equalTo: root.widthAnchor),
            notesLabel.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])
    }

    /// 内容に合わせてパネルの高さを決める (幅は固定、非リサイズ。autosave された旧サイズも上書きする)
    private func fitWindowToContent() {
        guard let window = window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = NSSize(width: ColorPickerPanelController.contentWidth, height: ceil(content.fittingSize.height))
        guard size.height > 0, size != content.frame.size else { return }
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.setContentSize(size)
        window.setFrameTopLeftPoint(topLeft)
    }

    // MARK: - Lock

    func setLocked(_ locked: Bool) {
        isLocked = locked
        Log.colorPicker.debug("panel setLocked(\(locked))")
    }

    private func updateTitle() {
        window?.title = isLocked ? "Color Picker 🔒 Locked" : "Color Picker"
    }

    /// パネルがキーのとき Esc で閉じる (通常は PDFView 側の keyDown が処理する)
    override func cancelOperation(_ sender: Any?) {
        close()
    }

    // MARK: - Options

    @objc private func displayModeChanged(_ sender: Any?) {
        guard let raw = displayPopup.selectedItem?.representedObject as? String,
              let mode = ColorDisplayMode(rawValue: raw) else { return }
        settings.displayMode = mode
    }

    @objc private func simulationChanged(_ sender: Any?) {
        guard let item = simulatePopup.selectedItem else { return }
        switch item.representedObject {
        case let path as String where path == "generic":
            settings.selectGenericCMYK()
        case let path as String where path == "rescan":
            settings.scanInstalledProfiles(force: true)
        case let path as String where path == "document":
            break   // 文書インテントは自動選択なので何もしない
        case let path as String:
            settings.selectInstalledProfile(path: path)
        default:
            break
        }
        syncPopups()
    }

    private func settingsDidChange() {
        rebuildSimulateMenu()
        syncPopups()
        rerender()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildSimulateMenu()
        syncPopups()
    }

    private func rebuildSimulateMenu() {
        guard let menu = simulatePopup.menu else { return }
        menu.removeAllItems()

        if let intent = settings.documentIntent {
            let item = NSMenuItem(title: "Document: \(intent.displayName)", action: nil, keyEquivalent: "")
            item.representedObject = "document"
            menu.addItem(item)
        } else if let other = settings.documentNonCMYKIntent {
            let item = NSMenuItem(title: "Document: \(other.displayName) (not CMYK, not used)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: "Document: no output intent", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())

        let generic = NSMenuItem(title: SimulationProfile.genericCMYK.description, action: nil, keyEquivalent: "")
        generic.representedObject = "generic"
        menu.addItem(generic)

        var listed = settings.installedProfiles
        // 保存済みの選択がまだ一覧に無ければ (走査前) 先に出す
        if case .installed(let path) = settings.userProfile.source,
           !listed.contains(where: { $0.path == path }) {
            listed.insert(InstalledProfile(path: path, description: settings.userProfile.description), at: 0)
        }
        for p in listed {
            let item = NSMenuItem(title: p.description, action: nil, keyEquivalent: "")
            item.representedObject = p.path
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let rescan = NSMenuItem(title: "Rescan Installed Profiles", action: nil, keyEquivalent: "")
        rescan.representedObject = "rescan"
        menu.addItem(rescan)
        // 項目は representedObject で判定するので、NSPopUpButton の標準の有効化に任せる
        simulatePopup.autoenablesItems = false
        for item in menu.items where item.isSeparatorItem == false {
            item.isEnabled = item.representedObject != nil
        }
    }

    /// 設定の現在値をポップアップの選択に反映する
    private func syncPopups() {
        if let idx = ColorDisplayMode.allCases.firstIndex(of: settings.displayMode) {
            displayPopup.selectItem(at: idx)
        }
        let target: String
        switch settings.activeProfile.source {
        case .documentIntent: target = "document"
        case .genericCMYK: target = "generic"
        case .installed(let path): target = path
        }
        if let item = simulatePopup.menu?.items.first(where: { ($0.representedObject as? String) == target }) {
            simulatePopup.select(item)
        }
        // 文書インテントがあるときはユーザー選択を受け付けない (Acrobat と同じ)
        simulatePopup.isEnabled = settings.documentIntent == nil
    }

    // MARK: - Updates

    func showNoPage() {
        lastHit = nil
        magnifierView.image = nil
        swatchView.layer?.backgroundColor = NSColor.clear.cgColor
        valuesLabel.stringValue = "—"
        srgbLabel.stringValue = ""
        spaceLabel.stringValue = "No page under the cursor"
        notesLabel.stringValue = ""
        positionLabel.stringValue = ""
        separationsHeader.stringValue = "Separations · \(settings.simulationName)"
        renderSeparations(nil)
        copyText = ""
        copyColor = nil
        copyButton.isEnabled = false
        copyPDFButton.isEnabled = false
        syncPopups()
    }

    func setMagnifier(_ image: NSImage?) {
        magnifierView.image = image
    }

    /// ヒット結果を表示する。`pageIndex` は 0 始まり。`pageSpots` はページ内の特色版。
    func update(hit: PDFColorHit, pageSpots: [CGPDFPageColorScanner.SpotPlate],
                pageLabel: String?, pageIndex: Int?, point: CGPoint?) {
        lastHit = hit
        lastSpots = pageSpots
        lastPageLabel = pageLabel
        lastPageIndex = pageIndex
        lastPoint = point
        rerender()
    }

    /// 最後のヒットを現在の設定で表示し直す
    func rerender() {
        guard let hit = lastHit else {
            showNoPage()
            return
        }
        let sim = settings.simulationSpace
        let simName = settings.simulationName
        let mode = settings.displayMode

        // --- スウォッチ ---
        let swatch = PDFColorReadout.sRGB(of: hit, simulation: sim)
        swatchView.layer?.backgroundColor = swatch?.cgColor ?? NSColor.clear.cgColor

        // --- 成分値 (縦並び) ---
        let displayColor: PDFPaintColor? = hit.sample?.color ?? hit.color
        let displayed = PDFColorReadout.display(hit, mode: mode, simulation: sim, simulationName: simName)
        var valueLines: [String] = []
        if let d = displayed {
            let labelWidth = d.pairs.map { $0.0.count }.max() ?? 1
            for (label, value) in d.pairs {
                let padded = label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
                valueLines.append("\(padded): \(value)")
            }
        }
        if valueLines.isEmpty {
            valueLines.append(hit.needsSampling && hit.sample == nil ? "(sampling…)" : "—")
        }
        valuesLabel.stringValue = valueLines.joined(separator: "\n")

        // --- 0–255 / ≈ sRGB ---
        var srgbParts: [String] = []
        if let l = displayed?.line255 {
            srgbParts.append(l)
        }
        if let c = swatch {
            srgbParts.append("≈ sRGB \(PDFPaintColor.hexString(c))")
        }
        srgbLabel.stringValue = srgbParts.joined(separator: "   ")

        // --- 色空間 · 対象 ---
        var spaceParts: [String] = []
        if let d = displayed, d.isApproximate {
            spaceParts.append(d.title)
        } else if let s = hit.sample {
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

        // --- 分版 ---
        separationsHeader.stringValue = "Separations · \(simName)"
        let plates = PDFColorReadout.plates(hit, pageSpots: lastSpots.map { $0.name }, simulation: sim, simulationName: simName)
        renderSeparations(plates)

        // --- 補足 ---
        var notes = hit.notes
        if let n = plates?.note { notes.insert(n, at: 0) }
        if let alt = hit.color?.alternateColor {
            notes.insert("alt \(alt.space.displayName): \(alt.formattedComponents)", at: 0)
        }
        if let sc = hit.strokeColor {
            notes.insert("stroke \(sc.space.displayName): \(sc.formattedComponents)", at: 0)
        }
        notesLabel.stringValue = notes.joined(separator: " · ")

        // --- 位置 ---
        var pos: [String] = []
        if let i = lastPageIndex {
            if let l = lastPageLabel, l != "\(i + 1)" {
                pos.append("p. \(l) (#\(i + 1))")
            } else {
                pos.append("p. \(i + 1)")
            }
        }
        if let p = lastPoint {
            pos.append(String(format: "(%.1f, %.1f) pt", p.x, p.y))
        }
        positionLabel.stringValue = pos.joined(separator: "  ")

        // --- Copy 用テキスト ---
        var copyLines: [String] = []
        var first = hit.sample.map { "\($0.color.space.displayName) (sampled)" } ?? hit.spaceDescription
        if let c = displayColor {
            first += "  " + c.formattedComponents
        }
        if let c = swatch {
            first += "  (≈ sRGB \(PDFPaintColor.hexString(c)))"
        }
        copyLines.append(first)
        if let d = displayed, d.isApproximate {
            copyLines.append("\(d.title): " + d.pairs.map { "\($0.0) \($0.1)" }.joined(separator: "  "))
        }
        if let p = plates {
            var line = "Separations (\(simName)): " + p.plates.map { "\($0.name) \(PDFColorReadout.formatTAC($0.fraction))" }.joined(separator: "  ")
            line += "  TAC \(PDFColorReadout.formatTAC(p.tac))"
            if p.isApproximate { line += " (≈)" }
            copyLines.append(line)
        }
        var second = hit.kindDescription
        if !pos.isEmpty { second += " — " + pos.joined(separator: ", ") }
        copyLines.append(second)
        if !notes.isEmpty { copyLines.append(notes.joined(separator: "; ")) }
        copyText = copyLines.joined(separator: "\n")
        copyButton.isEnabled = true
        copyColor = displayColor
        copyColorIsSampled = hit.sample != nil
        copyPDFButton.isEnabled = canCopyPDF

        syncPopups()
        fitWindowToContent()
    }

    private func renderSeparations(_ plates: PDFColorReadout.PlatesReadout?) {
        guard let p = plates else {
            for row in separationRows { row.isHidden = true }
            tacLabel.stringValue = ""
            return
        }
        let sim = settings.simulationSpace
        var shown = p.plates
        var overflow = 0
        let maxRows = 4 + ColorPickerPanelController.maxSpotRows
        if shown.count > maxRows {
            overflow = shown.count - maxRows
            shown = Array(shown.prefix(maxRows))
        }
        while separationRows.count < shown.count + 1 {
            let row = SeparationRowView()
            separationRows.append(row)
            separationsStack.addArrangedSubview(row)
        }
        for (i, plate) in shown.enumerated() {
            let row = separationRows[i]
            let spot = lastSpots.first { $0.name == plate.name }
            let chip = PDFColorReadout.plateChipColor(name: plate.name, spot: spot, simulation: sim)
            row.set(name: plate.name, value: PDFColorReadout.formatTAC(plate.fraction), chip: chip,
                    approximate: p.isApproximate && plate.isProcess)
            row.isHidden = false
        }
        var next = shown.count
        if overflow > 0 {
            separationRows[next].set(name: "+\(overflow) more", value: "", chip: nil, approximate: false)
            separationRows[next].isHidden = false
            next += 1
        }
        for i in next..<separationRows.count { separationRows[i].isHidden = true }

        var tac = "TAC \(PDFColorReadout.formatTAC(p.tac))"
        if p.isApproximate { tac = "≈ " + tac }
        let limit = CGFloat(settings.tacLimit) / 100
        if p.tac > limit + 0.0005 {
            tac += "  ⚠︎ > \(settings.tacLimit)%"
            tacLabel.textColor = .systemOrange
        } else {
            tacLabel.textColor = .labelColor
        }
        tacLabel.stringValue = tac
    }

    // MARK: - Copy

    /// 値をテキストでクリップボードへ (Digital Color Meter の ⇧⌘C 相当)
    @objc func copyColorAsText(_ sender: Any?) {
        guard !copyText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(copyText, forType: .string)
    }

    /// 色で塗った小さな矩形をベクタ PDF でクリップボードへ (色空間定義つき)。
    /// テキストも一緒に載せるので、PDF を受け取れない貼り先には値の文字列が入る。
    @objc func copyColorAsPDF(_ sender: Any?) {
        guard let color = copyColor,
              let pdf = PDFColorSwatchWriter.pdfData(for: color) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(pdf, forType: .pdf)
        var text = copyText
        if let note = PDFColorSwatchWriter.prepare(color)?.note {
            text += "\n(PDF: \(note))"
        }
        if copyColorIsSampled {
            text += "\n(PDF swatch uses the sampled value)"
        }
        pb.setString(text, forType: .string)
        Log.colorPicker.info("copied color as PDF (\(pdf.count) bytes)")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        isLocked = false
        onClose?()
    }
}

/// 分版リストの 1 行: 色チップ + 版名 + %
final class SeparationRowView: NSView {
    private let chip = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 2
        chip.layer?.borderWidth = 1
        chip.layer?.borderColor = NSColor.separatorColor.cgColor
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.widthAnchor.constraint(equalToConstant: 12).isActive = true
        chip.heightAnchor.constraint(equalToConstant: 12).isActive = true

        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.widthAnchor.constraint(equalToConstant: 118).isActive = true

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let stack = NSStackView(views: [chip, nameLabel, valueLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func set(name: String, value: String, chip color: NSColor?, approximate: Bool) {
        nameLabel.stringValue = name
        valueLabel.stringValue = approximate && !value.isEmpty ? "≈" + value : value
        chip.layer?.backgroundColor = color?.cgColor ?? NSColor.clear.cgColor
        chip.isHidden = color == nil && name.hasPrefix("+")
    }
}
