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
// AppDelegate の拡張: View メニュー関連 (Zoom系 & ページナビゲーション系 & 表示モード)
// ==========================================
extension AppDelegate {

    // Zoom系
    @objc func zoomInAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = false
            view?.zoomIn(sender)
        }
    }

    @objc func zoomOutAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = false
            view?.zoomOut(sender)
        }
    }

    @objc func autoResizeAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = true
            view?.layoutDocumentView()
        }
    }

    @objc func actualSizeAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = false
            view?.scaleFactor = 1.0
        }
    }

    // ページナビゲーション系
    @objc func nextPageAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.goToNextPage(sender)
        }
    }

    @objc func previousPageAction(_ sender: Any?) {
        for view in [pdfViewA, pdfViewB] {
            view?.goToPreviousPage(sender)
        }
    }

    // 表示モード変更系
    @objc func changeDisplayMode(_ sender: NSMenuItem) {
        let mode: PDFDisplayMode
        switch sender.title {
        case "Single Page":
            mode = .singlePage
        case "Single Page Continuous":
            mode = .singlePageContinuous
        case "Two Pages":
            mode = .twoUp
        case "Two Pages Continuous":
            mode = .twoUpContinuous
        default:
            return
        }

        // 変更されたモードを UserDefaults に保存
        UserDefaults.standard.set(mode.rawValue, forKey: "displayMode")

        // リロード時の不整合を防ぐため、A/B両方のビューに反映する
        for view in [pdfViewA, pdfViewB] {
            view?.displayMode = mode
        }
    }

    @objc func toggleBookModeAction(_ sender: NSMenuItem) {
        let newState = !(self.activePDFView.displaysAsBook)

        // Book Modeの状態を UserDefaults に保存
        UserDefaults.standard.set(newState, forKey: "displaysAsBook")

        for view in [pdfViewA, pdfViewB] {
            view?.displaysAsBook = newState
        }
    }

    @objc func toggleRTLAction(_ sender: NSMenuItem) {
        let newState = !(self.activePDFView.displaysRTL)

        // RTLの状態を UserDefaults に保存
        UserDefaults.standard.set(newState, forKey: "displaysRTL")

        for view in [pdfViewA, pdfViewB] {
            view?.displaysRTL = newState
        }
    }
}
