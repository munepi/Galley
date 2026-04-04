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

// ==========================================
// AppDelegate の拡張: About Galley の表示処理
// ==========================================
extension AppDelegate {

    @objc func showAbout(_ sender: Any?) {
        // 既に表示されているAboutビューがあれば先に削除
        if let existingView = self.container.subviews.first(where: { $0.identifier?.rawValue == "AboutView" }) {
            existingView.removeFromSuperview()
        }

        // 1. 背景ビューの作成
        let aboutView = NSView()
        aboutView.wantsLayer = true
        aboutView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        aboutView.layer?.cornerRadius = 16
        aboutView.layer?.borderColor = NSColor.separatorColor.cgColor
        aboutView.layer?.borderWidth = 1
        aboutView.translatesAutoresizingMaskIntoConstraints = false
        aboutView.identifier = NSUserInterfaceItemIdentifier("AboutView")

        // 2. 中身を縦に並べる StackView
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        // --- コンテンツの構築 ---

        // ロゴ
        // 読み込めなかった場合のフォールバックとして doc のシンボルを指定
        let logoImage = NSImage(named: "GalleyPDF") ?? NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Galley Logo")
        let logoImageView = NSImageView(image: logoImage!)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.widthAnchor.constraint(equalToConstant: 96).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: 96).isActive = true

        // アプリ名
        let nameLabel = NSTextField(labelWithString: "Galley")
        nameLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false

        // バージョン
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let versionLabel = NSTextField(labelWithString: "Version \(versionString)")
        versionLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.isEditable = false
        versionLabel.isBordered = false
        versionLabel.drawsBackground = false

        // プロジェクトURL (クリック可能)
        let urlLabel = NSTextField(labelWithString: "https://github.com/munepi/Galley")
        urlLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        urlLabel.textColor = .linkColor // リンク色（青など）にする
        urlLabel.isEditable = false
        urlLabel.isBordered = false
        urlLabel.drawsBackground = false

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(openProjectURL(_:)))
        urlLabel.addGestureRecognizer(clickGesture)

        // Copyright
        let copyrightLabel = NSTextField(labelWithString: "Copyright © 2026 Munehiro Yamamoto.\nAll rights reserved.")
        copyrightLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center
        copyrightLabel.isEditable = false
        copyrightLabel.isBordered = false
        copyrightLabel.drawsBackground = false

        // StackView に要素を追加
        stack.addArrangedSubview(logoImageView)
        stack.setCustomSpacing(12, after: logoImageView)
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(versionLabel)
        stack.setCustomSpacing(16, after: versionLabel)
        stack.addArrangedSubview(urlLabel)
        stack.setCustomSpacing(16, after: urlLabel)
        stack.addArrangedSubview(copyrightLabel)

        aboutView.addSubview(stack)
        self.container.addSubview(aboutView)

        // 3. 制約 (Auto Layout) の設定
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: aboutView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: aboutView.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: aboutView.widthAnchor, constant: -64),
            stack.heightAnchor.constraint(equalTo: aboutView.heightAnchor, constant: -64),

            aboutView.centerXAnchor.constraint(equalTo: self.container.centerXAnchor),
            aboutView.centerYAnchor.constraint(equalTo: self.container.centerYAnchor),
            aboutView.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])

        // 4. 表示状態にして、5秒後に消す
        aboutView.alphaValue = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if aboutView.superview != nil {
                aboutView.removeFromSuperview()
            }
        }
    }

    // URLをクリックしたときにブラウザで開く処理
    @objc func openProjectURL(_ sender: NSClickGestureRecognizer) {
        if let url = URL(string: "https://github.com/munepi/Galley") {
            NSWorkspace.shared.open(url) // デフォルトブラウザで開く

            // クリックされたら、5秒待たずにAbout画面を閉じる
            if let aboutView = self.container.subviews.first(where: { $0.identifier?.rawValue == "AboutView" }) {
                aboutView.removeFromSuperview()
            }
        }
    }
}
