import AppKit
import PDFKit

// ==========================================
// カスタムPDFView: 矩形選択ツール ＆ 寸法・コピー機能 ＆ ページジャンプ機能 ＆ 文字情報機能
// ==========================================
class GalleyPDFView: PDFView {
    // フォーカス管理 (First Responder)
    // キーボード入力を受け付けることをOSに宣言
    override var acceptsFirstResponder: Bool {
        return true
    }
    // ウィンドウに配置された（表示された）瞬間に、自動でフォーカスを取得する
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            window.makeFirstResponder(self)
            // ウィンドウ上でマウスが動いたイベントを受け取る
            window.acceptsMouseMovedEvents = true
        }
    }

    // --- 矩形選択用のプロパティ ---
    var selectionStartPoint: CGPoint?
    var currentSelectionRect: NSRect?
    var selectedPage: PDFPage?
    var marqueeLayer: CAShapeLayer?
    var dimensionLabel: NSTextField?

    // 矩形領域の移動用のプロパティ
    private var isDraggingMarquee: Bool = false
    private var dragStartMousePoint: CGPoint?
    private var dragStartMarqueeRect: NSRect?

    // --- ページジャンプ用のプロパティ ---
    private var pageInputBuffer: String = ""
    private var pageInputTimer: Timer?
    private var pageInputHUD: NSTextField?

    // マウス操作 (Inverse Search, 矩形選択, リンクジャンプ)
    override func mouseDown(with event: NSEvent) {

        // --- 0. Inverse Search (Cmd + Click) ---
        if event.modifierFlags.contains(.command) {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.performInverseSearch(event: event, view: self)
            }
            return
        }

        // --- 1. 矩形選択ツール (Shift + Click) ---
        if event.modifierFlags.contains(.shift) {
            let location = self.convert(event.locationInWindow, from: nil)
            guard let page = self.page(for: location, nearest: true) else { return }
            let pagePoint = self.convert(location, to: page)

            if let currentRect = currentSelectionRect, self.selectedPage == page, currentRect.contains(pagePoint) {
                self.isDraggingMarquee = true
                self.dragStartMousePoint = pagePoint
                self.dragStartMarqueeRect = currentRect
            } else {
                self.clearSelection()
                self.clearMarquee()
                CATransaction.flush()

                self.selectedPage = page
                self.selectionStartPoint = pagePoint
                self.currentSelectionRect = NSRect(origin: pagePoint, size: .zero)

                setupMarquee()
                updateMarquee()
            }
        } else {
            // --- 2. 通常のクリック (リンクジャンプ等) ---
            let location = self.convert(event.locationInWindow, from: nil)

            // PDFKitが提供するリンク判定
            let area = self.areaOfInterest(for: location)
            var isLink = area.contains(.linkArea)

            // フォールバック判定 (特殊なLaTeXリンク用)
            if !isLink, let page = self.page(for: location, nearest: true) {
                let pagePoint = self.convert(location, to: page)
                if let annotation = page.annotation(at: pagePoint), annotation.type == "Link" {
                    isLink = true
                }
            }

            if isLink {
                // ★超重要: リンクの場合は、クリア処理を呼ばずPDFKit標準に完全に任せる！
                super.mouseDown(with: event)
                return
            }

            // 何もない場所をクリックした場合は、選択ツールをクリアして標準処理へ
            self.clearSelection()
            self.clearMarquee()
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)

        // 1. 移動モード中の処理
        if isDraggingMarquee, let startMouse = dragStartMousePoint, let startRect = dragStartMarqueeRect, let page = selectedPage {
            let pagePoint = self.convert(location, to: page)

            // マウスの移動量(差分)を計算して、元の矩形を移動させる
            let dx = pagePoint.x - startMouse.x
            let dy = pagePoint.y - startMouse.y
            self.currentSelectionRect = startRect.offsetBy(dx: dx, dy: dy)

            updateMarquee()
        }
        // 2. 新規作成モード中の処理
        else if let startPoint = selectionStartPoint, let page = selectedPage {
            let pagePoint = self.convert(location, to: page)

            let rect = NSRect(
                x: min(startPoint.x, pagePoint.x),
                y: min(startPoint.y, pagePoint.y),
                width: abs(pagePoint.x - startPoint.x),
                height: abs(pagePoint.y - startPoint.y)
            )
            self.currentSelectionRect = rect

            updateMarquee()
        }
        // 3. どちらでもない場合はPDFKit標準の処理へ
        else {
            super.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        // 移動モードの終了
        if isDraggingMarquee {
            isDraggingMarquee = false
            dragStartMousePoint = nil
            dragStartMarqueeRect = nil
        }
        // 新規作成モードの終了
        else if selectionStartPoint != nil {
            selectionStartPoint = nil
        }
        else {
            super.mouseUp(with: event)
        }
    }

    // キーボード操作 (ページジャンプ ＆ Escキーでクリア)
    override func keyDown(with event: NSEvent) {
        // Escキー (keyCode: 53) が押されたら、もろもろの選択・入力をキャンセルする

        if event.keyCode == 53 {
            // 1. PDFKit標準のテキスト選択などをクリア
            self.clearSelection()

            // 2. カスタムの矩形選択ツールをクリア
            self.clearMarquee()

            // 3. ページジャンプの入力途中であれば、それもキャンセルしてHUDを消す
            if !pageInputBuffer.isEmpty {
                pageInputBuffer = ""
                pageInputTimer?.invalidate()
                hidePageInputHUD()
            }
            return
        }

        // Command, Control, Option などの修飾キーが押されている場合は、
        // ページジャンプの入力とはみなさず、通常のショートカット処理へ譲る
        if event.modifierFlags.intersection([.command, .control, .option]).isEmpty == false {
            super.keyDown(with: event)
            return
        }

        // [0-9a-z] の入力を検知してバッファに追加 (大文字も小文字に正規化して許容)
        if let chars = event.charactersIgnoringModifiers, let char = chars.first {
            let s = String(char).lowercased()
            if s.range(of: "^[0-9a-z]$", options: .regularExpression) != nil {
                pageInputBuffer.append(s)
                updatePageInputHUD()
                resetPageInputTimer()
                return
            }
        }

        // スペースキー（ページ送り）など、対象外のキーはPDFKitに処理させる
        super.keyDown(with: event)
    }


    // --- 選択文字の解析情報を一時保持する構造体 ---
    struct CharacterInspectionInfo {
        let charStr: String
        let unicodeStr: String
        let glyphIDStr: String
        let unicodeName: String
        let unicodePlane: String
        let unicodeCategory: String
        let fontName: String
        let familyName: String
        let traits: String
        let pt: CGFloat
        let mm: CGFloat
        let q: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        let leading: CGFloat
        let selectionBounds: NSRect
        let page: PDFPage
    }
    var pendingInspectionInfo: CharacterInspectionInfo?

    // ==========================================
    // コンテキストメニュー (右クリック) のカスタマイズ
    // ==========================================
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu(title: "")

        guard let selection = self.currentSelection,
              let attrString = selection.attributedString,
              attrString.length > 0 else {
            return menu
        }

        let rawString = attrString.string
        guard let firstChar = rawString.first else { return menu }
        let charStr = String(firstChar)

        let attributes = attrString.attributes(at: 0, effectiveRange: nil)
        guard let font = attributes[.font] as? NSFont else { return menu }

        guard let scalar = firstChar.unicodeScalars.first else { return menu }
        let unicodeVal = scalar.value
        let unicodeStr = String(format: "U+%04X", unicodeVal)

        let unicodeName = scalar.properties.name?.capitalized ?? "Unknown"
        let unicodePlane = getUnicodePlaneName(value: unicodeVal)
        let unicodeCategory = getUnicodeCategoryName(category: scalar.properties.generalCategory)

        // --- フォント情報の詳細抽出 (CoreText) ---
        let ctFont = font as CTFont
        let rawFontName = (CTFontCopyPostScriptName(ctFont) as String?) ?? font.fontName
        let fontName = (rawFontName == "Helvetica") ? "Helvetica (fallback)" : rawFontName

        let familyName = (CTFontCopyFamilyName(ctFont) as String?) ?? font.familyName ?? "Unknown"

        // Traits (属性) の抽出
        let symbolicTraits = CTFontGetSymbolicTraits(ctFont)
        var traitStrings: [String] = []
        if symbolicTraits.contains(.traitBold) { traitStrings.append("Bold") }
        if symbolicTraits.contains(.traitItalic) { traitStrings.append("Italic") }
        if symbolicTraits.contains(.traitMonoSpace) { traitStrings.append("Mono") }
        if symbolicTraits.contains(.traitCondensed) { traitStrings.append("Condensed") }
        let traits = traitStrings.isEmpty ? "Regular" : traitStrings.joined(separator: ", ")

        // Metrics (垂直メトリクス) の抽出
        let ascent = CTFontGetAscent(ctFont)
        let descent = CTFontGetDescent(ctFont)
        let leading = CTFontGetLeading(ctFont)

        let pt = font.pointSize
        let mm = pt * (25.4 / 72.0)
        let q = mm * 4.0

        var glyphIDStr = "N/A"
        let utf16Chars = Array(charStr.utf16)
        if !utf16Chars.isEmpty {
            var glyphs = [CGGlyph](repeating: 0, count: utf16Chars.count)
            if CTFontGetGlyphsForCharacters(ctFont, utf16Chars, &glyphs, utf16Chars.count) {
                glyphIDStr = "\(glyphs[0])"
            }
        }

        guard let page = selection.pages.first else { return menu }
        let bounds = selection.bounds(for: page)

        self.pendingInspectionInfo = CharacterInspectionInfo(
            charStr: charStr, unicodeStr: unicodeStr, glyphIDStr: glyphIDStr,
            unicodeName: unicodeName, unicodePlane: unicodePlane, unicodeCategory: unicodeCategory,
            fontName: fontName, familyName: familyName, traits: traits,
            pt: pt, mm: mm, q: q, ascent: ascent, descent: descent, leading: leading,
            selectionBounds: bounds, page: page
        )

        let inspectionItem = NSMenuItem(title: "Inspect Character \"\(charStr)\"", action: #selector(showCharacterInspection), keyEquivalent: "")
        inspectionItem.target = self
        if let icon = NSImage(systemSymbolName: "text.magnifyingglass", accessibilityDescription: nil) {
            inspectionItem.image = icon
        }

        menu.insertItem(NSMenuItem.separator(), at: 0)
        menu.insertItem(inspectionItem, at: 0)

        return menu
    }

    // ==========================================
    // Popover (吹き出しUI) で文字情報を表示する
    // ==========================================
    @objc func showCharacterInspection() {
        guard let info = pendingInspectionInfo else { return }

        let isCJK = info.charStr.unicodeScalars.first?.properties.isIdeographic == true ||
                    info.charStr.range(of: "\\p{Hiragana}|\\p{Katakana}", options: .regularExpression) != nil
        let cidNote = (info.glyphIDStr != "N/A" && isCJK) ? " (≒ CID)" : ""

        let infoText = """
        Char:  \(info.charStr)
        Code:  \(info.unicodeStr)
        Glyph: \(info.glyphIDStr)\(cidNote)

        [ Unicode Info ]
        Name:  \(info.unicodeName)
        Plane: \(info.unicodePlane)
        Cat:   \(info.unicodeCategory)

        [ Font Info ]
        Font:   \(info.fontName)
        Family: \(info.familyName)
        Traits: \(info.traits)
        Size:   \(String(format: "%.2f pt", info.pt)) = \(String(format: "%.2f mm", info.mm)) = \(String(format: "%.2f Q", info.q))
        Metric: Asc \(String(format: "%.2f", info.ascent)), Des \(String(format: "%.2f", info.descent)), Ldg \(String(format: "%.2f", info.leading))
        """

        let displayFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // --- Popover のサイズを動的に計算する ---
        let attributes: [NSAttributedString.Key: Any] = [.font: displayFont]

        // 修正 1: .greatestFiniteMagnitude に CGFloat を明示
        let boundingSize = (infoText as NSString).boundingRect(
            with: NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attributes
        ).size

        // 余白を足して最終的なViewサイズを決定
        let popoverWidth = max(340, ceil(boundingSize.width) + 40)
        let popoverHeight = ceil(boundingSize.height) + 40

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let viewController = NSViewController()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))

        let textView = NSTextView(frame: NSRect(x: 15, y: 15, width: popoverWidth - 30, height: popoverHeight - 30))
        textView.string = infoText
        textView.font = displayFont

        // 修正 2: NSColor を明示
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.clear

        textView.isEditable = false
        textView.isSelectable = true // 選択＆コピー可能

        view.addSubview(textView)
        viewController.view = view
        popover.contentViewController = viewController

        let targetRect = self.convert(info.selectionBounds, from: info.page)
        popover.show(relativeTo: targetRect, of: self, preferredEdge: .maxY)
    }

    // --- Unicode 解析用ヘルパー関数 ---
    private func getUnicodePlaneName(value: UInt32) -> String {
        let planeIndex = value >> 16
        switch planeIndex {
        case 0: return "Basic Multilingual Plane (BMP)"
        case 1: return "Supplementary Multilingual Plane (SMP)"
        case 2: return "Supplementary Ideographic Plane (SIP)"
        case 3: return "Tertiary Ideographic Plane (TIP)"
        case 14: return "Supplementary Special-purpose Plane (SSP)"
        default: return "Plane \(planeIndex)"
        }
    }

    private func getUnicodeCategoryName(category: Unicode.GeneralCategory) -> String {
        switch category {
        case .uppercaseLetter: return "Uppercase Letter (Lu)"
        case .lowercaseLetter: return "Lowercase Letter (Ll)"
        case .titlecaseLetter: return "Titlecase Letter (Lt)"
        case .modifierLetter: return "Modifier Letter (Lm)"
        case .otherLetter: return "Other Letter (Lo)"
        case .nonspacingMark: return "Nonspacing Mark (Mn)"
        case .spacingMark: return "Spacing Mark (Mc)"
        case .enclosingMark: return "Enclosing Mark (Me)"
        case .decimalNumber: return "Decimal Number (Nd)"
        case .letterNumber: return "Letter Number (Nl)"
        case .otherNumber: return "Other Number (No)"
        case .connectorPunctuation: return "Connector Punctuation (Pc)"
        case .dashPunctuation: return "Dash Punctuation (Pd)"
        case .openPunctuation: return "Open Punctuation (Ps)"
        case .closePunctuation: return "Close Punctuation (Pe)"
        case .initialPunctuation: return "Initial Punctuation (Pi)"
        case .finalPunctuation: return "Final Punctuation (Pf)"
        case .otherPunctuation: return "Other Punctuation (Po)"
        case .mathSymbol: return "Math Symbol (Sm)"
        case .currencySymbol: return "Currency Symbol (Sc)"
        case .modifierSymbol: return "Modifier Symbol (Sk)"
        case .otherSymbol: return "Other Symbol (So)"
        case .spaceSeparator: return "Space Separator (Zs)"
        case .lineSeparator: return "Line Separator (Zl)"
        case .paragraphSeparator: return "Paragraph Separator (Zp)"
        case .control: return "Control (Cc)"
        case .format: return "Format (Cf)"
        case .surrogate: return "Surrogate (Cs)"
        case .privateUse: return "Private Use (Co)"
        case .unassigned: return "Unassigned (Cn)"
        @unknown default: return "Unknown"
        }
    }

    private func resetPageInputTimer() {
        pageInputTimer?.invalidate()
        // 最後の入力から1.0秒経過したら自動的に確定してジャンプ
        pageInputTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.commitPageInput()
        }
    }

    private func updatePageInputHUD() {
        if pageInputHUD == nil {
            let label = NSTextField(labelWithString: "")

            // AppKit標準の四角い背景描画を無効化！
            label.drawsBackground = false
            label.isBordered = false
            label.isEditable = false
            label.isSelectable = false
            label.textColor = .white
            label.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
            label.alignment = .center

            // 代わりにレイヤーを使って背景色と角丸を描画
            label.wantsLayer = true
            label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
            label.layer?.masksToBounds = true

            self.addSubview(label)
            self.pageInputHUD = label
        }

        guard let hud = pageInputHUD else { return }

        // 余白を持たせるために前後にスペースを入れる
        hud.stringValue = "  Page: \(pageInputBuffer)  "
        hud.sizeToFit()

        let hudSize = hud.frame.size
        // 高さに応じて完全な角丸（カプセル型）を適用
        hud.layer?.cornerRadius = hudSize.height / 2.0

        let viewSize = self.bounds.size
        let bottomMargin: CGFloat = 40.0

        // ウィンドウ下部への配置
        let xPos = (viewSize.width - hudSize.width) / 2
        let yPos = self.isFlipped ? (viewSize.height - hudSize.height - bottomMargin) : bottomMargin

        hud.frame = NSRect(x: xPos, y: yPos, width: hudSize.width, height: hudSize.height)
        hud.alphaValue = 1.0
    }

    private func hidePageInputHUD() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.pageInputHUD?.animator().alphaValue = 0.0
        }, completionHandler: {
            self.pageInputHUD?.removeFromSuperview()
            self.pageInputHUD = nil
        })
    }

    private func commitPageInput() {
        pageInputTimer?.invalidate()
        let target = pageInputBuffer.lowercased()
        pageInputBuffer = ""

        guard let doc = self.document, target.isEmpty == false else {
            hidePageInputHUD()
            return
        }

        var targetPage: PDFPage? = nil
        let pageCount = doc.pageCount

        // 1. 論理ページ番号（nombre）での大文字小文字を区別しない検索
        for i in 0..<pageCount {
            if let page = doc.page(at: i),
               let label = page.label?.lowercased(),
               label == target {
                targetPage = page
                break
            }
        }

        // 2. 見つからなければ、物理ページ番号（1始まり）としてフォールバック
        if targetPage == nil, let physicalIndex = Int(target), physicalIndex > 0, physicalIndex <= pageCount {
            targetPage = doc.page(at: physicalIndex - 1)
        }

        if let page = targetPage {
            self.go(to: page)
            hidePageInputHUD()
        } else {
            // エラー表示の見た目と位置も更新
            pageInputHUD?.stringValue = "  Page \(target) Not Found  "
            pageInputHUD?.textColor = NSColor.systemRed
            pageInputHUD?.sizeToFit()

            if let hud = pageInputHUD {
                let hudSize = hud.frame.size
                hud.layer?.cornerRadius = hudSize.height / 2.0
                let viewSize = self.bounds.size
                let bottomMargin: CGFloat = 40.0

                let xPos = (viewSize.width - hudSize.width) / 2
                let yPos = self.isFlipped ? (viewSize.height - hudSize.height - bottomMargin) : bottomMargin
                hud.frame = NSRect(x: xPos, y: yPos, width: hudSize.width, height: hudSize.height)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.hidePageInputHUD()
            }
        }
    }

    // 描画とコピー処理
    private func setupMarquee() {
        if marqueeLayer == nil {
            let layer = CAShapeLayer()
            layer.strokeColor = NSColor.systemTeal.cgColor
            layer.fillColor = NSColor.systemTeal.withAlphaComponent(0.2).cgColor
            layer.lineWidth = 1.0
            layer.lineDashPattern = [4, 4]
            layer.zPosition = 9999
            self.documentView?.wantsLayer = true
            self.documentView?.layer?.addSublayer(layer)
            self.marqueeLayer = layer
        }
        if dimensionLabel == nil {
            let label = NSTextField(labelWithString: "")
            label.backgroundColor = NSColor.black.withAlphaComponent(0.75)
            label.textColor = .white
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.drawsBackground = true
            label.isBordered = false
            label.isEditable = false
            label.isSelectable = false
            label.layer?.cornerRadius = 4
            label.layer?.masksToBounds = true
            self.addSubview(label)
            self.dimensionLabel = label
        }
    }

    private func updateMarquee() {
        guard let rect = currentSelectionRect, let page = selectedPage,
              let layer = marqueeLayer, let label = dimensionLabel else { return }

        let viewRect = self.convert(rect, from: page)
        guard let docView = self.documentView else { return }
        let docRect = self.convert(viewRect, to: docView)

        layer.path = CGPath(rect: docRect, transform: nil)

        let widthMM = rect.width * 25.4 / 72.0
        let heightMM = rect.height * 25.4 / 72.0
        label.stringValue = String(format: " %.1f mm × %.1f mm ", widthMM, heightMM)
        label.sizeToFit()

        var labelFrame = label.frame
        labelFrame.origin.x = viewRect.midX - labelFrame.width / 2

        if self.isFlipped {
            labelFrame.origin.y = viewRect.maxY + 4
        } else {
            labelFrame.origin.y = viewRect.minY - labelFrame.height - 4
        }
        label.frame = labelFrame
    }

    private func clearMarquee() {
        marqueeLayer?.removeFromSuperlayer()
        marqueeLayer = nil
        dimensionLabel?.removeFromSuperview()
        dimensionLabel = nil
        currentSelectionRect = nil
        selectedPage = nil
    }

    @objc override func copy(_ sender: Any?) {
        if let rect = currentSelectionRect, let page = selectedPage {
            guard let pageCopy = page.copy() as? PDFPage else { return }

            pageCopy.setBounds(rect, for: .mediaBox)
            pageCopy.setBounds(rect, for: .cropBox)
            pageCopy.setBounds(rect, for: .bleedBox)
            pageCopy.setBounds(rect, for: .trimBox)
            pageCopy.setBounds(rect, for: .artBox)

            let tempDoc = PDFDocument()
            tempDoc.insert(pageCopy, at: 0)

            if let pdfData = tempDoc.dataRepresentation() {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setData(pdfData, forType: .pdf)

                let flash = CABasicAnimation(keyPath: "opacity")
                flash.fromValue = 1.0
                flash.toValue = 0.0
                flash.duration = 0.15
                flash.autoreverses = true
                marqueeLayer?.add(flash, forKey: "flashAnimation")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.clearMarquee()
            }
        } else {
            super.copy(sender)
        }
    }

    // ==========================================
    // トラッキングエリア (Hover時の👆カーソル変更)
    // ==========================================
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            self.removeTrackingArea(ta)
        }
        guard let docView = self.documentView else { return }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: docView.bounds, options: options, owner: self, userInfo: nil)
        docView.addTrackingArea(trackingArea!)
    }

    override func mouseMoved(with event: NSEvent) {
        // 1. まず必ず PDFKit 標準の処理(テキスト上のIビームカーソル化など)を呼ぶ
        super.mouseMoved(with: event)

        // 2. その直後に、マウスの下が「リンク」であれば 👆 カーソルで上書きする
        guard let docView = self.documentView else { return }
        let locationInDocView = docView.convert(event.locationInWindow, from: nil)
        guard let page = self.page(for: locationInDocView, nearest: true) else { return }
        let pagePoint = self.convert(locationInDocView, to: page)

        if let annotation = page.annotation(at: pagePoint), annotation.type == "Link" {
            NSCursor.pointingHand.set()
        }
    }
}
