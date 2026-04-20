// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import Foundation

/// PDFDocumentInfo を Markdown / JSON に直列化する
enum PDFInfoExporter {

    static func markdown(_ info: PDFDocumentInfo, title: String = "PDF Info") -> String {
        var out = "# \(title)\n"
        for sec in info.sections {
            out += "\n## \(sec.title)\n\n"
            for row in sec.rows {
                switch row {
                case .keyValue(let k, let v):
                    out += "- **\(k)**: \(escapeInline(v))\n"
                case .longText(let label, let v):
                    out += "\n### \(label)\n\n```\n\(v)\n```\n"
                }
            }
        }
        return out
    }

    static func json(_ info: PDFDocumentInfo) -> String {
        var sections: [[String: Any]] = []
        for sec in info.sections {
            var rows: [[String: Any]] = []
            for row in sec.rows {
                switch row {
                case .keyValue(let k, let v):
                    rows.append(["key": k, "value": v])
                case .longText(let l, let v):
                    rows.append(["key": l, "value": v, "longText": true])
                }
            }
            sections.append(["title": sec.title, "rows": rows])
        }
        let root: [String: Any] = ["sections": sections]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    private static func escapeInline(_ s: String) -> String {
        // Markdown テーブル/行内での改行は半角スペースに潰す
        return s.replacingOccurrences(of: "\n", with: " ")
    }
}
