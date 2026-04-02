import AppKit
import PDFKit

// ==========================================
// AppDelegate の拡張: PDF テキスト検索機能
// ==========================================
extension AppDelegate {

    private static let searchBarHeight: CGFloat = 36.0

    // ==========================================
    // 検索バーの生成とウィンドウへの配置
    // ==========================================
    func setupSearchBar() {
        guard let contentView = window?.contentView else { return }

        // --- コンテナ ---
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        bar.layer?.borderColor = NSColor.separatorColor.cgColor
        bar.layer?.borderWidth = 0.5

        // --- 検索フィールド ---
        let field = NSSearchField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholderString = "Search"
        field.controlSize = .small
        field.font = .systemFont(ofSize: 13)
        field.focusRingType = .none
        field.target = self
        field.action = #selector(searchFieldAction(_:))
        field.delegate = self
        field.sendsSearchStringImmediately = true

        // --- 一致数ラベル ---
        let countLabel = NSTextField(labelWithString: "")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // --- 前/次ボタン ---
        let prevBtn = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous")!, target: self, action: #selector(searchPreviousAction(_:)))
        prevBtn.translatesAutoresizingMaskIntoConstraints = false
        prevBtn.bezelStyle = .inline
        prevBtn.isBordered = false
        prevBtn.setContentHuggingPriority(.required, for: .horizontal)

        let nextBtn = NSButton(image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next")!, target: self, action: #selector(searchNextAction(_:)))
        nextBtn.translatesAutoresizingMaskIntoConstraints = false
        nextBtn.bezelStyle = .inline
        nextBtn.isBordered = false
        nextBtn.setContentHuggingPriority(.required, for: .horizontal)

        // --- 正規表現チェックボックス ---
        let regexCheck = NSButton(checkboxWithTitle: "Regex", target: self, action: #selector(regexToggleAction(_:)))
        regexCheck.translatesAutoresizingMaskIntoConstraints = false
        regexCheck.controlSize = .small
        regexCheck.font = .systemFont(ofSize: 11)
        regexCheck.setContentHuggingPriority(.required, for: .horizontal)

        // --- 閉じるボタン ---
        let closeBtn = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!, target: self, action: #selector(closeSearchBarAction(_:)))
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.bezelStyle = .inline
        closeBtn.isBordered = false
        closeBtn.setContentHuggingPriority(.required, for: .horizontal)

        bar.addSubview(field)
        bar.addSubview(countLabel)
        bar.addSubview(prevBtn)
        bar.addSubview(nextBtn)
        bar.addSubview(regexCheck)
        bar.addSubview(closeBtn)

        contentView.addSubview(bar)

        // --- 制約 ---
        let topConstraint = bar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -AppDelegate.searchBarHeight)

        NSLayoutConstraint.activate([
            topConstraint,
            bar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: AppDelegate.searchBarHeight),

            field.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            field.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),

            countLabel.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 8),
            countLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            prevBtn.leadingAnchor.constraint(equalTo: countLabel.trailingAnchor, constant: 4),
            prevBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            nextBtn.leadingAnchor.constraint(equalTo: prevBtn.trailingAnchor, constant: 2),
            nextBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            regexCheck.leadingAnchor.constraint(equalTo: nextBtn.trailingAnchor, constant: 12),
            regexCheck.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            closeBtn.leadingAnchor.constraint(greaterThanOrEqualTo: regexCheck.trailingAnchor, constant: 8),
            closeBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            closeBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])

        self.searchBarContainer = bar
        self.searchBarTopConstraint = topConstraint
        self.searchField = field
        self.searchMatchCountLabel = countLabel
        self.searchRegexCheckbox = regexCheck
    }

    // ==========================================
    // 表示/非表示の切り替え
    // ==========================================
    @objc func toggleSearchBar(_ sender: Any?) {
        if searchBarVisible {
            hideSearchBar()
        } else {
            showSearchBar()
        }
    }

    func showSearchBar() {
        guard let window = self.window else { return }
        if searchBarContainer == nil { setupSearchBar() }

        // タイトルバーの高さを取得して、その直下に配置
        let titleBarHeight = window.frame.height - window.contentLayoutRect.height
        searchBarTopConstraint?.constant = titleBarHeight

        searchBarContainer?.superview?.layoutSubtreeIfNeeded()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.searchBarContainer?.superview?.layoutSubtreeIfNeeded()
        }

        searchBarVisible = true
        window.makeFirstResponder(searchField)

        // 既にテキストが入力されていたら選択状態にし、再検索する
        if let field = searchField, !field.stringValue.isEmpty {
            field.selectText(nil)
            performSearch()
        }
    }

    func hideSearchBar() {
        searchBarTopConstraint?.constant = -AppDelegate.searchBarHeight

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.searchBarContainer?.superview?.layoutSubtreeIfNeeded()
        }, completionHandler: {
            self.clearSearchHighlights()
        })

        searchBarVisible = false

        // フォーカスをPDFViewに戻す
        window?.makeFirstResponder(activePDFView)
    }

    // ==========================================
    // 検索アクション
    // ==========================================
    @objc func searchFieldAction(_ sender: NSSearchField) {
        performSearch()
    }

    @objc func searchNextAction(_ sender: Any?) {
        guard !searchResults.isEmpty else { return }
        searchCurrentIndex = (searchCurrentIndex + 1) % searchResults.count
        highlightCurrentMatch()
    }

    @objc func searchPreviousAction(_ sender: Any?) {
        guard !searchResults.isEmpty else { return }
        searchCurrentIndex = (searchCurrentIndex - 1 + searchResults.count) % searchResults.count
        highlightCurrentMatch()
    }

    @objc func regexToggleAction(_ sender: NSButton) {
        performSearch()
    }

    @objc func closeSearchBarAction(_ sender: Any?) {
        hideSearchBar()
    }

    // ==========================================
    // 検索ロジック
    // ==========================================
    func performSearch() {
        guard let query = searchField?.stringValue, !query.isEmpty,
              let doc = activePDFView.document else {
            clearSearchHighlights()
            return
        }

        let useRegex = (searchRegexCheckbox?.state == .on)

        if useRegex {
            searchResults = performRegexSearch(query, in: doc)
        } else {
            searchResults = doc.findString(query, withOptions: [.caseInsensitive])
        }

        searchCurrentIndex = nearestMatchIndex()
        updateMatchCountLabel()

        if !searchResults.isEmpty {
            highlightCurrentMatch()
        } else {
            clearSearchHighlights()
        }
    }

    /// 現在表示中のページ以降で最も近いマッチのインデックスを返す
    private func nearestMatchIndex() -> Int {
        guard !searchResults.isEmpty,
              let currentPage = activePDFView.currentPage,
              let doc = activePDFView.document else { return 0 }

        let currentPageIndex = doc.index(for: currentPage)

        for (i, sel) in searchResults.enumerated() {
            if let selPage = sel.pages.first {
                let selPageIndex = doc.index(for: selPage)
                if selPageIndex >= currentPageIndex {
                    return i
                }
            }
        }

        return 0
    }

    private func performRegexSearch(_ pattern: String, in doc: PDFDocument) -> [PDFSelection] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            updateMatchCountLabel(error: true)
            return []
        }

        var results: [PDFSelection] = []

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i),
                  let pageString = page.string else { continue }

            let nsString = pageString as NSString
            let matches = regex.matches(in: pageString, range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if let selection = page.selection(for: match.range) {
                    results.append(selection)
                }
            }
        }

        return results
    }

    // ==========================================
    // ハイライト表示
    // ==========================================
    private func highlightCurrentMatch() {
        guard searchCurrentIndex < searchResults.count else { return }

        let current = searchResults[searchCurrentIndex]

        // 全マッチをハイライト（黄色系）
        let highlights = searchResults.map { sel -> PDFSelection in
            sel.color = NSColor.systemYellow.withAlphaComponent(0.35)
            return sel
        }

        // 現在のマッチを強調（オレンジ系）
        current.color = NSColor.systemOrange.withAlphaComponent(0.6)

        activePDFView.highlightedSelections = highlights
        activePDFView.go(to: current)
        activePDFView.setCurrentSelection(current, animate: true)

        updateMatchCountLabel()
    }

    func clearSearchHighlights() {
        searchResults = []
        searchCurrentIndex = 0
        activePDFView.highlightedSelections = nil
        activePDFView.clearSelection()
        updateMatchCountLabel()
    }

    private func updateMatchCountLabel(error: Bool = false) {
        guard let label = searchMatchCountLabel else { return }

        if error {
            label.stringValue = "Invalid regex"
            label.textColor = .systemRed
            return
        }

        label.textColor = .secondaryLabelColor

        if searchResults.isEmpty {
            if let query = searchField?.stringValue, !query.isEmpty {
                label.stringValue = "Not found"
            } else {
                label.stringValue = ""
            }
        } else {
            label.stringValue = "\(searchCurrentIndex + 1) / \(searchResults.count)"
        }
    }
}

// ==========================================
// NSSearchField のキーイベント処理
// (Escape で閉じる、Enter/Shift+Enter でナビゲーション)
// ==========================================
extension AppDelegate: NSSearchFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control == searchField else { return false }

        // Escape → 検索バーを閉じる
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            hideSearchBar()
            return true
        }

        // Enter → 次の一致 / Shift+Enter → 前の一致
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                searchPreviousAction(nil)
            } else {
                searchNextAction(nil)
            }
            return true
        }

        return false
    }
}
