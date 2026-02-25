import AppKit
import PDFKit

// ==========================================
// カスタムPDFView: 矩形選択ツール ＆ 寸法・コピー機能 ＆ ページジャンプ機能
// ==========================================
class LeafPDFView: PDFView {
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

    // マウス操作 (矩形選択と移動など)
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) {
            let location = self.convert(event.locationInWindow, from: nil)
            guard let page = self.page(for: location, nearest: true) else { return }
            let pagePoint = self.convert(location, to: page)

            // 1. 既存の矩形領域の内側をクリックしたか判定 (移動モード)
            if let currentRect = currentSelectionRect, self.selectedPage == page, currentRect.contains(pagePoint) {
                self.isDraggingMarquee = true
                self.dragStartMousePoint = pagePoint
                self.dragStartMarqueeRect = currentRect
            }
            // 2. 矩形領域の外側をクリックした場合は、新規作成モード
            else {
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
}
