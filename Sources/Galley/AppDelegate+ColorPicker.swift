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
// AppDelegate の拡張: Color Picker パネルの開閉とメニュー連携
// ==========================================
extension AppDelegate {

    /// パネルが表示されている間が「カラーピッカーモード」
    var isColorPickerActive: Bool {
        return colorPickerController?.window?.isVisible ?? false
    }

    @objc func toggleColorPicker(_ sender: Any?) {
        if isColorPickerActive {
            closeColorPicker()
        } else {
            openColorPicker(from: activePDFView, viewPoint: nil)
        }
    }

    /// パネルを開く。`viewPoint` (PDFView 座標) が渡されればその点を直ちに読む。
    func openColorPicker(from view: GalleyPDFView?, viewPoint: CGPoint?) {
        if colorPickerController == nil {
            let controller = ColorPickerPanelController()
            controller.onClose = { [weak self] in
                self?.colorPickerDidClose()
            }
            colorPickerController = controller
        }
        guard let controller = colorPickerController else { return }

        for v in [pdfViewA, pdfViewB] {
            v?.colorPickerResetState()
        }
        controller.setLocked(false)
        controller.showWindow(nil)
        controller.window?.orderFront(nil)

        let target = view ?? activePDFView
        if let p = viewPoint {
            target.colorPickerUpdate(atViewPoint: p)
        } else if let win = target.window {
            let p = target.convert(win.mouseLocationOutsideOfEventStream, from: nil)
            if target.bounds.contains(p) {
                target.colorPickerUpdate(atViewPoint: p)
            } else {
                controller.showNoPage()
            }
        }
        NSCursor.crosshair.set()
        Log.colorPicker.info("color picker opened")
    }

    func closeColorPicker() {
        colorPickerController?.close()   // → windowWillClose → colorPickerDidClose
    }

    private func colorPickerDidClose() {
        for v in [pdfViewA, pdfViewB] {
            v?.colorPickerResetState()
        }
        NSCursor.arrow.set()
        Log.colorPicker.info("color picker closed")
    }

    /// 文書が差し替わった (loadPDF / reloadPDF)。ページオブジェクトが変わるので
    /// ロックを解除し、キャッシュを捨てる。パネルは開いたまま。
    func colorPickerDocumentDidChange() {
        PDFColorScanCache.shared.flush()
        guard isColorPickerActive else { return }
        for v in [pdfViewA, pdfViewB] {
            v?.colorPickerResetState()
        }
        colorPickerController?.setLocked(false)
        colorPickerController?.showNoPage()
    }

    // MARK: - Edit ▸ Copy Color as Text / PDF (Digital Color Meter と同じ ⇧⌘C / ⌥⌘C)

    @objc func copyColorAsText(_ sender: Any?) {
        colorPickerController?.copyColorAsText(sender)
    }

    @objc func copyColorAsPDF(_ sender: Any?) {
        colorPickerController?.copyColorAsPDF(sender)
    }

    func validateCopyColorMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard isColorPickerActive, let panel = colorPickerController else { return false }
        if menuItem.action == #selector(copyColorAsPDF(_:)) {
            return panel.canCopyPDF
        }
        return panel.canCopyText
    }

    func validateColorPickerMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.state = isColorPickerActive ? .on : .off
        // ウィンドウ構築前にも validate が走りうるので optional で受ける
        let view: GalleyPDFView? = isShowingA ? pdfViewA : pdfViewB
        return view?.document != nil || isColorPickerActive
    }
}
