import AppKit
import PDFKit

// ==========================================
// カスタムPDFView: 矩形選択ツール ＆ 寸法・コピー機能
// ==========================================
class LeafPDFView: PDFView {
    var selectionStartPoint: CGPoint?
    var currentSelectionRect: NSRect?
    var selectedPage: PDFPage?

    var marqueeLayer: CAShapeLayer?
    var dimensionLabel: NSTextField?

    override func mouseDown(with event: NSEvent) {
        // --- 1. Shiftキーを押しながらのクリック（矩形選択の開始） ---
        if event.modifierFlags.contains(.shift) {

            self.clearSelection()
            self.clearMarquee()
            CATransaction.flush() // 描画の即時反映を強制

            let location = self.convert(event.locationInWindow, from: nil)
            guard let page = self.page(for: location, nearest: true) else { return }
            self.selectedPage = page

            let pagePoint = self.convert(location, to: page)
            self.selectionStartPoint = pagePoint
            self.currentSelectionRect = NSRect(origin: pagePoint, size: .zero)

            setupMarquee()
            updateMarquee()
        }
        // --- 2. 通常のクリック ---
        else {
            // どこかをクリックした瞬間に、既存のテキスト選択と矩形選択を両方とも消す
            self.clearSelection()
            self.clearMarquee()

            // self.currentSelection = nil
            // CATransaction.flush()

            // PDFKit標準のマウスダウン処理に引き継ぐ
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = selectionStartPoint, let page = selectedPage else {
            super.mouseDragged(with: event)
            return
        }

        let location = self.convert(event.locationInWindow, from: nil)
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

    override func mouseUp(with event: NSEvent) {
        if selectionStartPoint != nil {
            selectionStartPoint = nil
        } else {
            super.mouseUp(with: event)
        }
    }

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

        // 実寸（ミリメートル）の計算
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

            // --- 描画を使わず、PDFのネイティブ機能でクロップ（切り抜き）する ---

            // 1. ページを複製する
            guard let pageCopy = page.copy() as? PDFPage else { return }

            // 2. 複製したページの表示枠（MediaBoxやCropBox）を、ドラッグした選択領域に強制的に書き換える
            pageCopy.setBounds(rect, for: .mediaBox)
            pageCopy.setBounds(rect, for: .cropBox)
            pageCopy.setBounds(rect, for: .bleedBox)
            pageCopy.setBounds(rect, for: .trimBox)
            pageCopy.setBounds(rect, for: .artBox)

            // 3. 新しい空のPDFドキュメントを作成し、クロップしたページを挿入する
            let tempDoc = PDFDocument()
            tempDoc.insert(pageCopy, at: 0)

            // 4. クリップボードに転送
            if let pdfData = tempDoc.dataRepresentation() {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setData(pdfData, forType: .pdf)

                // コピー成功のフラッシュエフェクト
                let flash = CABasicAnimation(keyPath: "opacity")
                flash.fromValue = 1.0
                flash.toValue = 0.0
                flash.duration = 0.15
                flash.autoreverses = true
                marqueeLayer?.add(flash, forKey: "flashAnimation")
            }

            // 少し待ってから選択を解除する
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.clearMarquee()
            }
        } else {
            // 矩形選択がなければ、標準のテキストコピーを処理する
            super.copy(sender)
        }
    }
}
