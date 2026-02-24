import AppKit

// ==========================================
// AppDelegate の拡張: About Leaf の表示処理
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

        // 仮ロゴ (SF Symbols の leaf.fill を緑色で表示)
        let logoImage = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Leaf Logo")
        let logoImageView = NSImageView(image: logoImage!)
        logoImageView.contentTintColor = NSColor.systemGreen
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        // アプリ名
        let nameLabel = NSTextField(labelWithString: "Leaf")
        nameLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false

        // バージョン
        let versionLabel = NSTextField(labelWithString: "Version 0.0")
        versionLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.isEditable = false
        versionLabel.isBordered = false
        versionLabel.drawsBackground = false

        // プロジェクトURL (クリック可能)
        let urlLabel = NSTextField(labelWithString: "https://github.com/munepi/Leaf")
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
        if let url = URL(string: "https://github.com/munepi/Leaf") {
            NSWorkspace.shared.open(url) // デフォルトブラウザで開く

            // クリックされたら、5秒待たずにAbout画面を閉じる
            if let aboutView = self.container.subviews.first(where: { $0.identifier?.rawValue == "AboutView" }) {
                aboutView.removeFromSuperview()
            }
        }
    }
}
