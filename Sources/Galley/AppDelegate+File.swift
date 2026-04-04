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
// AppDelegate の拡張: File メニューおよびファイル管理関連
// ==========================================
extension AppDelegate {

    // NOTE: (0.1, 0.2, 0.05)でも大丈夫そう
    struct DelaySettings {
        static let pollingInterval: TimeInterval = 0.1  // 0.2 // ファイル変更を監視する間隔
        static let reloadWait: TimeInterval = 0.2       // 0.4 // 変更検知からリロード処理を開始するまでの待機時間
        static let swapWait: TimeInterval = 0.05        // 0.15 // 裏で読み込みが完了してから画面を入れ替えるまでの待機時間
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["pdf"]
        if panel.runModal() == .OK, let url = panel.url { self.loadPDF(url: url) }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename).absoluteURL
        self.fileURL = url

        guard self.pdfViewA != nil else {
            return true
        }

        loadPDF(url: url)

        return true
    }

    func loadPDF(url: URL) {
        if let modal = NSApp.modalWindow, modal is NSOpenPanel {
            NSApp.stopModal()
            modal.close()
        }

        // 保留中のリロード/スワップ操作をキャンセル（前ファイルの監視由来の競合防止）
        self.timer?.invalidate()
        self.reloadWorkItem?.cancel()
        self.reloadWorkItem = nil
        self.swapWorkItem?.cancel()
        self.swapWorkItem = nil

        self.fileURL = url.absoluteURL
        guard let document = PDFDocument(url: url) else { return }

        self.activePDFView.document = document

        self.updateWindowTitle()

        startMonitoring(url: url)

        // open -a 経由で開いた場合にウィンドウを前面化
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func printDocument(_ sender: Any?) {
        guard let document = self.activePDFView.document,
              let window = self.window else { return }

        let printInfo = NSPrintInfo.shared
        let printOp = document.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: true)
        printOp?.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    // --- ファイル監視と自動リロード機構 ---
    func startMonitoring(url: URL) {
        let path = url.path
        self.lastUpdate = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)

        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: DelaySettings.pollingInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  let currentModDate = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date),
                  let lastMod = self.lastUpdate,
                  currentModDate > lastMod else { return }

            self.lastUpdate = currentModDate
            self.reloadWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.reloadPDF()
            }
            self.reloadWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + DelaySettings.reloadWait, execute: workItem)
        }
    }

    func reloadPDF() {
        guard let url = self.fileURL else { return }

        let activeView = self.activePDFView
        let hiddenView = self.hiddenPDFView

        var currentPageIndex = 0
        var currentPoint = CGPoint.zero
        if let dest = activeView.currentDestination, let page = dest.page, let doc = activeView.document {
            currentPageIndex = doc.index(for: page)
            currentPoint = dest.point
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // LaTeXコンパイラがPDFを生成途中しているにおける安全装置
            guard let data = try? Data(contentsOf: url),
                  let newDocument = PDFDocument(data: data), // ← 不完全なPDFのとき、ここで nil になる
                  newDocument.pageCount > 0 else { return } // ← nil ならば、処理を中断 (return) する

            DispatchQueue.main.async {
                hiddenView.document = newDocument
                if currentPageIndex < newDocument.pageCount,
                   let newPage = newDocument.page(at: currentPageIndex) {
                    let newDest = PDFDestination(page: newPage, at: currentPoint)
                    hiddenView.go(to: newDest)
                }

                hiddenView.autoScales = activeView.autoScales
                if !activeView.autoScales {
                    hiddenView.scaleFactor = activeView.scaleFactor
                }

                self.clearSearchHighlights()

                self.swapWorkItem?.cancel()
                let swapItem = DispatchWorkItem {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)

                    hiddenView.removeFromSuperview()
                    self.container.addSubview(hiddenView)

                    self.isShowingA.toggle()

                    activeView.document = nil
                    self.window?.makeFirstResponder(hiddenView)

                    CATransaction.commit()

                    self.updateWindowTitle()
                }
                self.swapWorkItem = swapItem

                DispatchQueue.main.asyncAfter(deadline: .now() + DelaySettings.swapWait, execute: swapItem)
            }
        }
    }

    @objc func handlePageChanged(_ notification: Notification) {
        updateWindowTitle()
    }

    func updateWindowTitle() {
        guard let window = self.window,
              let url = self.fileURL,
              let document = activePDFView.document else { return }

        // ウィンドウにファイルのURLを紐付ける
        window.representedURL = url

        // 無理やりGalleyのアイコンにすり替える☃
        if let iconButton = window.standardWindowButton(.documentIconButton) {
            // アプリ自身のアイコン(NSApplication.shared.applicationIconImage)で強制上書き
            iconButton.image = NSApplication.shared.applicationIconImage
        }

        let fileName = url.lastPathComponent
        let totalPages = document.pageCount

        // 現在表示されているページ番号を取得 (0始まりなので+1する)
        // currentPageが取得できない場合(nilの場合)は暫定で1ページ目とする
        let currentPage = activePDFView.currentPage ?? document.page(at: 0)
        let physicalPage = (currentPage != nil) ? (document.index(for: currentPage!) + 1) : 1

        // 論理ページ(label)の取得と表示の分岐
        if let page = currentPage, let label = page.label, label != "\(physicalPage)" {
            // 論理ページが存在し、かつ物理ページと異なる場合 (例: iv, cover, ☃ など)
            window.title = "\(fileName) - Page \(label) (\(physicalPage)/\(totalPages))"
        } else {
            // 論理ページが設定されていない、または物理ページと一致する場合
            window.title = "\(fileName) - Page \(physicalPage)/\(totalPages)"
        }
    }

}
