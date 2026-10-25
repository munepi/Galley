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
// AppDelegate の拡張: 最後の表示位置の記録と復元 (Issue #15)
// ==========================================
// 文書を離れるとき (別の PDF を開く、終了する) に位置を記録し、次に開いたときに戻す。
// Forward Search と `galleypdf open --page` は loadPDF(restorePosition: false) で開くので、
// そちらの位置が常に勝つ。復元は loadPDF の中で同期的に終わるため、後から上書きもしない。

enum ReadingPositionDefaults {
    static let key = "restoreLastPosition"
}

extension AppDelegate {

    var restoresLastPosition: Bool {
        return UserDefaults.standard.bool(forKey: ReadingPositionDefaults.key)
    }

    /// オフの間は記録も復元もしない (既存の記録は残す)
    @objc func toggleRestoreLastPosition(_ sender: Any?) {
        UserDefaults.standard.set(!restoresLastPosition, forKey: ReadingPositionDefaults.key)
    }

    /// 表示中の文書の位置を記録する (書き出しは saveIfNeeded)。
    func recordReadingPosition() {
        // 終了時はウィンドウ構築前でも呼ばれうるので optional で受ける
        let activeView: GalleyPDFView? = isShowingA ? pdfViewA : pdfViewB
        guard restoresLastPosition,
              let url = self.fileURL,
              let view = activeView,
              let document = view.document,
              let dest = view.currentDestination,
              let page = dest.page else { return }

        // reloadPDF と同じく、ページ番号とページ内の位置で持つ
        let pageIndex = document.index(for: page)
        readingPositionStore.record(url: url, pageCount: document.pageCount, pageIndex: pageIndex,
                                    point: dest.point, autoScales: view.autoScales,
                                    scaleFactor: view.scaleFactor)
        Log.file.info("readingPosition: recorded page \(pageIndex + 1) of \(url.lastPathComponent, privacy: .public)")
    }

    /// 開いたばかりの文書を、前回の位置へ戻す。記録が無いか、ページ数が変わっていれば何もしない。
    func restoreReadingPosition(url: URL, document: PDFDocument) {
        guard restoresLastPosition,
              let entry = readingPositionStore.entry(for: url, pageCount: document.pageCount),
              let page = document.page(at: entry.pageIndex) else { return }

        // 倍率はズーム系の操作と同じく A/B 両方へ (リロード時の不整合を防ぐ)
        for view in [pdfViewA, pdfViewB] {
            view?.autoScales = entry.autoScales
            if !entry.autoScales {
                view?.scaleFactor = CGFloat(entry.scaleFactor)
            }
        }

        let point = CGPoint(x: entry.pointX, y: entry.pointY)
        self.activePDFView.go(to: PDFDestination(page: page, at: point))
        Log.file.info("readingPosition: restored page \(entry.pageIndex + 1) of \(url.lastPathComponent, privacy: .public)")
    }
}
