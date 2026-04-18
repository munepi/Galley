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
import CSynctex

// ==========================================
// AppDelegate の拡張: Forward Search 関連の処理
// ==========================================
extension AppDelegate {

    func setupForwardSearch() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleForwardSearchEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(0x474C4C59), // 'GLLY'
            andEventID: AEEventID(0x6677646a)        // 'fwdj'
        )
    }

    @objc func handleForwardSearchEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let lineStr = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let line = Int32(lineStr) else { return }
        let pdfPath = event.paramDescriptor(forKeyword: AEKeyword(0x70646650))?.stringValue
        let srcPath = event.paramDescriptor(forKeyword: AEKeyword(0x73726346))?.stringValue

        self.processForwardSearch(line: line, column: nil, pdfPath: pdfPath, srcPath: srcPath)
        replyEvent.setDescriptor(NSAppleEventDescriptor(string: "OK"), forKeyword: keyDirectObject)
    }

    func processForwardSearch(line: Int32, column: Int32? = nil, pdfPath: String?, srcPath: String?) {
        let pdfName = (pdfPath as NSString?)?.lastPathComponent ?? "nil"

        // 1. srcPath が省略された場合、PDFのパスから .tex ファイルを推測するフォールバック
        let guessedSrcPath = srcPath ?? (pdfPath as NSString?)?.deletingPathExtension.appending(".tex")
        let srcName = (guessedSrcPath as NSString?)?.lastPathComponent ?? "nil"

        let colStr = column != nil ? " | Col: \(column!)" : ""
        let baseMessage = "Forward Search ➔ PDF: \(pdfName) | Src: \(srcName) | Line: \(line)\(colStr)"
        Log.forwardSearch.debug("\(baseMessage, privacy: .public)")

        if let pPath = pdfPath {
            let url = URL(fileURLWithPath: pPath).absoluteURL
            if self.fileURL?.path != url.path {
                self.loadPDF(url: url)
            }
        }
        guard let currentPDFPath = self.fileURL?.path else { return }
        guard let scanner = synctex_scanner_new_with_output_file(currentPDFPath, nil, 1) else { return }
        defer { synctex_scanner_free(scanner) }

        // 2. CSynctex に NULL を渡してクラッシュするのを防ぐガード
        guard let finalSrcPath = guessedSrcPath,
              let srcCStr = (finalSrcPath as NSString).utf8String else {
            Log.forwardSearch.error("Source path is missing or invalid.")
            return
        }

        var searchLine = line
        var isLineShifted = false
        // エディタから column = 0 (行頭) が指定された場合、1行下をターゲットにする
        if let col = column, col == 0 {
            searchLine = line + 1
            isLineShifted = true
        }

        var querySuccess = false
        if synctex_display_query(scanner, srcCStr, searchLine, 0, -1) > 0 {
            querySuccess = true
            Log.forwardSearch.debug("SyncTeX query succeeded.")
        } else {
            if isLineShifted {
                // エディタからの column が最終行だった場合、元のlineとする
                searchLine = line
                if synctex_display_query(scanner, srcCStr, searchLine, 0, -1) > 0 {
                    querySuccess = true
                    Log.forwardSearch.debug("SyncTeX query succeeded.")
                }
            } else {
                Log.forwardSearch.debug("SyncTeX query failed or matched.")
            }
        }

        if querySuccess {
            if let node = synctex_scanner_next_result(scanner) {
                let pageIndex = synctex_node_page(node) - 1

                let rawX = CGFloat(synctex_node_h(node))
                let rawY = CGFloat(synctex_node_v(node))

                if let document = self.activePDFView.document,
                   let page = document.page(at: Int(pageIndex)) {

                    let bounds = page.bounds(for: .cropBox)

                    // 1. DVI unit (sp) -> TeX point (pt) への変換
                    let texPtX = rawX / 65536.0
                    let texPtY = rawY / 65536.0

                    // 2. TeX point (72.27 pt/inch) -> PDF point (72.0 pt/inch) への変換
                    let pdfOffsetX = texPtX * (72.0 / 72.27)
                    let pdfOffsetY = texPtY * (72.0 / 72.27)

                    // 3. TeXの原点オフセット（左上から 1 inch, 1 inch の位置が原点）を加算
                    // 1 inch = 72.0 PDF points
                    let absolutePDFX = pdfOffsetX + 72.0
                    let absolutePDFY = pdfOffsetY + 72.0

                    // 4. PDFKitの座標系（左下原点）にY軸を反転させる
                    // bounds.maxY は用紙全体の高さ（例: A4判なら約842）
                    let finalPdfX = absolutePDFX
                    let finalPdfY = bounds.maxY - absolutePDFY

                    let flippedY = finalPdfY
                    let pdfX = finalPdfX

                    let detailMessage = """
                    Page: \(pageIndex + 1)
                    Raw (sp): Y=\(String(format: "%.0f", rawY))
                    Absolute PDF: X=\(String(format: "%.1f", absolutePDFX)), Y=\(String(format: "%.1f", absolutePDFY))
                    Flipped Y: \(String(format: "%.1f", flippedY))
                    Bounds height: \(String(format: "%.1f", bounds.maxY))
                    """

                    Log.forwardSearch.debug("\(detailMessage, privacy: .public)")

                    let visibleHeight = self.activePDFView.bounds.height
                    let scale = self.activePDFView.scaleFactor
                    let halfHeightInPDF = (visibleHeight / scale) / 2.0
                    let centeredY = flippedY + halfHeightInPDF

                    let dest = PDFDestination(page: page, at: CGPoint(x: pdfX > 0 ? pdfX : 0, y: centeredY))
                    self.activePDFView.go(to: dest)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        guard let docView = self.activePDFView.documentView else { return }

                        // --- 1. 古い赤丸 (OLD) があれば削除する ---
                        let dotIdentifier = NSUserInterfaceItemIdentifier("ForwardSearchDot")
                        docView.subviews.filter { $0.identifier == dotIdentifier }.forEach { oldDot in
                            oldDot.removeFromSuperview()
                        }

                        // --- 2. 古いテキスト選択をクリアする ---
                        self.activePDFView.clearSelection()

                        // --- 3. 該当行のテキストを「選択状態(Selection)」にする ---
                        let selectionHeight: CGFloat = 20.0
                        let lineRect = NSRect(x: 0,
                                              y: flippedY - (selectionHeight / 2),
                                              width: bounds.width,
                                              height: selectionHeight)

                        if let selection = page.selection(for: lineRect) {
                            self.activePDFView.currentSelection = selection
                        } else {
                            Log.forwardSearch.debug("No text found at Y: \(flippedY) to select.")
                        }

                        // --- 4. 新しい赤丸 (NEW) の座標計算と生成 ---
                        let pdfPoint = CGPoint(x: pdfX > 0 ? pdfX : 30, y: flippedY)
                        let viewPoint = self.activePDFView.convert(pdfPoint, from: page)
                        let docPoint = self.activePDFView.convert(viewPoint, to: docView)

                        let dotSize: CGFloat = 16.0
                        let dotView = NSView(frame: NSRect(x: docPoint.x - (dotSize / 2),
                                                           y: docPoint.y - (dotSize / 2),
                                                           width: dotSize, height: dotSize))
                        dotView.wantsLayer = true

                        // 識別子をセット (次回検索して消せるようにするため)
                        dotView.identifier = dotIdentifier

                        let circleLayer = CAShapeLayer()
                        let circleRect = CGRect(x: 1, y: 1, width: dotSize - 2, height: dotSize - 2)
                        circleLayer.path = CGPath(ellipseIn: circleRect, transform: nil)
                        circleLayer.fillColor = NSColor.systemRed.withAlphaComponent(0.9).cgColor
                        circleLayer.strokeColor = NSColor.white.cgColor
                        circleLayer.lineWidth = 0.1

                        circleLayer.shadowColor = NSColor.black.cgColor
                        circleLayer.shadowOpacity = 0.5
                        circleLayer.shadowRadius = 2.0
                        circleLayer.shadowOffset = CGSize(width: 0, height: -1)

                        dotView.layer?.addSublayer(circleLayer)

                        // 新しい赤丸を画面に追加
                        docView.addSubview(dotView)

                        // 3秒後に赤丸だけをフェードアウトして削除 (テキスト選択は残る)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            if dotView.superview != nil {
                                NSAnimationContext.runAnimationGroup({ context in
                                    context.duration = 0.3
                                    dotView.animator().alphaValue = 0.0
                                }) {
                                    dotView.removeFromSuperview()
                                }
                            }
                        }
                    }
                }
            } else {
                Log.forwardSearch.error("SyncTeX matched no nodes.")
            }
        } else {
            Log.forwardSearch.error("SyncTeX query failed.")
        }
    }

    // ==========================================
    // 画面上に通知（HUD）を表示する機能
    // ==========================================
    func showNotification(_ message: String) {
        let label = NSTextField(labelWithString: message)
        label.font = .monospacedSystemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        label.drawsBackground = true
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 8
        label.layer?.masksToBounds = true

        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0

        label.sizeToFit()
        label.frame.size.width += 40
        label.frame.size.height += 20

        let containerBounds = self.container.bounds
        label.frame.origin.x = (containerBounds.width - label.frame.width) / 2
        label.frame.origin.y = 40

        self.container.addSubview(label)

        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                label.animator().alphaValue = 0.0
            }) {
                label.removeFromSuperview()
            }
        }
    }
}
