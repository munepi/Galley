// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit
import PDFKit

/// 中身を実装するまでの共通プレースホルダ
class PlaceholderSubPanelViewController: NSViewController {
    let message: String
    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let v = NSView()
        let label = NSTextField(labelWithString: message)
        label.textColor = .secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        self.view = v
    }

    func reload(document: PDFDocument?, url: URL?) {
        // placeholder: 何もしない
    }
}


