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
// GalleyPDFView の拡張: Color Picker モード中のマウス処理と値の計算
//
// - mouseMoved: カーソル下をヒットテストしてパネルを更新
// - 左クリック: ロック / 解除
// - 画像・シェーディングはカーソル静止後にラスタサンプリング
// - 拡大鏡の再描画は 1 フレーム 1 回に間引く
// ==========================================
extension GalleyPDFView {

    var isColorPickerActive: Bool {
        return (NSApp.delegate as? AppDelegate)?.isColorPickerActive ?? false
    }

    private var colorPickerPanel: ColorPickerPanelController? {
        return (NSApp.delegate as? AppDelegate)?.colorPickerController
    }

    /// ロック状態はパネルが唯一の持ち主 (PDFView は A/B の 2 枚あるため)
    var colorPickerLocked: Bool {
        return colorPickerPanel?.isLocked ?? false
    }

    // MARK: - Event hooks (called from GalleyPDFView)

    func colorPickerHandleMouseMoved(_ event: NSEvent) {
        NSCursor.crosshair.set()
        guard !colorPickerLocked else { return }
        let p = self.convert(event.locationInWindow, from: nil)
        colorPickerUpdate(atViewPoint: p)
    }

    /// 左クリック: ロックのトグル。ロック時はクリック位置の値で固定する。
    /// ダブルクリックの 2 回目以降は無視する (ロック→即解除になるのを防ぐ)。
    func colorPickerHandleMouseDown(_ event: NSEvent) {
        guard event.clickCount <= 1 else { return }
        let p = self.convert(event.locationInWindow, from: nil)
        if colorPickerLocked {
            colorPickerPanel?.setLocked(false)
            colorPickerUpdate(atViewPoint: p)
            Log.colorPicker.info("mouseDown: unlocked at (\(p.x), \(p.y)) clickCount=\(event.clickCount)")
        } else {
            colorPickerUpdate(atViewPoint: p)
            colorPickerPanel?.setLocked(true)
            Log.colorPicker.info("mouseDown: locked at (\(p.x), \(p.y)) clickCount=\(event.clickCount)")
        }
    }

    func colorPickerHandleMouseExited() {
        guard !colorPickerLocked else { return }
        colorPickerSampleTimer?.invalidate()
        colorPickerSampleTimer = nil
        colorPickerPanel?.showNoPage()
    }

    func colorPickerResetState() {
        Log.colorPicker.debug("resetState")
        colorPickerSampleTimer?.invalidate()
        colorPickerSampleTimer = nil
        colorPickerLastPage = nil
        colorPickerLastHit = nil
    }

    /// コンテキストメニューの「Color Picker」
    @objc func colorPickerFromContextMenu(_ sender: Any?) {
        let p = pendingColorPickViewPoint
        (NSApp.delegate as? AppDelegate)?.openColorPicker(from: self, viewPoint: p)
    }

    // MARK: - Core update

    func colorPickerUpdate(atViewPoint viewPoint: CGPoint) {
        guard let panel = colorPickerPanel else { return }
        guard let page = self.page(for: viewPoint, nearest: false) else {
            colorPickerSampleTimer?.invalidate()
            colorPickerSampleTimer = nil
            colorPickerLastPage = nil
            panel.showNoPage()
            return
        }

        let pagePoint = self.convert(viewPoint, to: page)
        let tolerance = 2.0 / max(self.scaleFactor, 0.01)
        let hit = PDFColorHitTester.hit(page: page, point: pagePoint, tolerance: tolerance)

        colorPickerLastPage = page
        colorPickerLastPoint = pagePoint
        colorPickerLastHit = hit

        let pageIndex = self.document?.index(for: page)
        panel.update(hit: hit, pageLabel: page.label, pageIndex: pageIndex, point: pagePoint)

        scheduleMagnifierRedraw()

        colorPickerSampleTimer?.invalidate()
        colorPickerSampleTimer = nil
        if hit.needsSampling {
            colorPickerSampleTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
                self?.performColorSampling()
            }
        }
    }

    private func scheduleMagnifierRedraw() {
        guard !colorPickerMagnifierScheduled else { return }
        colorPickerMagnifierScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.colorPickerMagnifierScheduled = false
            guard self.isColorPickerActive,
                  let page = self.colorPickerLastPage,
                  let point = self.colorPickerLastPoint else { return }
            let image = PDFColorSampler.magnifierImage(
                page: page, center: point,
                extent: ColorPickerPanelController.magnifierExtent,
                pixels: ColorPickerPanelController.magnifierPixels)
            self.colorPickerPanel?.setMagnifier(image)
        }
    }

    private func performColorSampling() {
        colorPickerSampleTimer = nil
        guard isColorPickerActive,
              let page = colorPickerLastPage,
              let point = colorPickerLastPoint,
              var hit = colorPickerLastHit,
              hit.needsSampling else { return }
        hit.sample = PDFColorSampler.sample(page: page, at: point, cmyk: hit.sampleInCMYK)
        if hit.sample == nil {
            hit.notes.append("sampling failed")
        }
        colorPickerLastHit = hit
        let pageIndex = self.document?.index(for: page)
        colorPickerPanel?.update(hit: hit, pageLabel: page.label, pageIndex: pageIndex, point: point)
    }

    // MARK: - Character inspector support

    /// 選択範囲の先頭文字の塗り色を、文字インスペクタ用のテキストにして返す
    func colorPickerInspectorLines(for selection: PDFSelection, on page: PDFPage) -> String {
        let lineSelection = selection.selectionsByLine().first ?? selection
        let lb = lineSelection.bounds(for: page)
        guard !lb.isNull, !lb.isEmpty else { return "Color:  n/a" }
        let probe = CGPoint(x: lb.minX + min(2.0, lb.width / 4), y: lb.midY)
        let index = page.characterIndex(at: probe)
        guard let hit = PDFColorHitTester.hitText(page: page, characterIndex: index),
              let color = hit.color else {
            return "Color:  n/a"
        }

        var lines: [String] = []
        lines.append("Space:  \(hit.spaceDescription)")
        lines.append("Value:  \(color.formattedComponents)")
        if let r = color.formatted255 {
            lines.append("        \(r)")
        }
        if let alt = color.alternateColor {
            lines.append("Alt:    \(alt.space.displayName) \(alt.formattedComponents)")
        }
        if let sc = hit.strokeColor {
            lines.append("Stroke: \(sc.space.displayName) \(sc.formattedComponents)")
        }
        if let c = hit.swatchColor {
            lines.append("sRGB:   ≈ \(PDFPaintColor.hexString(c))")
        }
        if hit.alpha < 1 {
            lines.append("Alpha:  \(String(format: "%.2f", hit.alpha))")
        }
        if !hit.notes.isEmpty {
            lines.append("Note:   \(hit.notes.joined(separator: "; "))")
        }
        return lines.joined(separator: "\n")
    }
}
