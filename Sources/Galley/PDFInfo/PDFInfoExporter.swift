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
