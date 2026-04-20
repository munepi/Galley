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

/// XMP 生XMLを PDFDocumentInfo のセクション列にパースする
enum XMPParser {

    /// 名前空間プレフィックスごとのセクション表示名とソート順
    private static let namespaceOrder: [(prefix: String, title: String)] = [
        ("dc", "Dublin Core"),
        ("xmp", "XMP Basic"),
        ("xmpRights", "XMP Rights"),
        ("pdf", "PDF"),
        ("pdfx", "PDF/X"),
        ("pdfaid", "PDF/A"),
        ("pdfuaid", "PDF/UA"),
        ("xmpMM", "Media Management"),
        ("xmpTPg", "Paged-Text"),
        ("photoshop", "Photoshop"),
        ("tiff", "TIFF"),
        ("exif", "EXIF"),
        ("crs", "Camera Raw"),
    ]

    static func parse(_ xml: String) -> PDFDocumentInfo {
        guard let data = xml.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: []) else {
            return .empty
        }

        let descriptions = (try? doc.nodes(forXPath: "//*[local-name()='Description']")) ?? []
        // プレフィックス → [(key, value)] に蓄積
        var buckets: [String: [(String, String)]] = [:]

        for descNode in descriptions {
            guard let desc = descNode as? XMLElement else { continue }

            // 短縮形: 属性として書かれたプロパティ
            for attr in desc.attributes ?? [] {
                guard let qname = attr.name, !qname.hasPrefix("xmlns") else { continue }
                let (prefix, local) = splitQName(qname)
                if prefix == "rdf" || prefix == "xml" { continue }
                if let v = attr.stringValue, !v.isEmpty {
                    buckets[prefix, default: []].append((local, v))
                }
            }

            // 長形式: 子要素として書かれたプロパティ
            for child in desc.children ?? [] {
                guard let el = child as? XMLElement, let qname = el.name else { continue }
                let (prefix, local) = splitQName(qname)
                let value = extractValue(from: el)
                if !value.isEmpty {
                    buckets[prefix, default: []].append((local, value))
                }
            }
        }

        // セクション化
        var sections: [InfoSection] = []
        var remaining = buckets
        for (prefix, title) in namespaceOrder {
            if let entries = remaining[prefix] {
                sections.append(buildSection(title: title, entries: entries))
                remaining.removeValue(forKey: prefix)
            }
        }
        // 未知の名前空間はアルファベット順
        for prefix in remaining.keys.sorted() {
            sections.append(buildSection(title: prefix.isEmpty ? "(default)" : prefix,
                                         entries: remaining[prefix]!))
        }
        return PDFDocumentInfo(sections: sections)
    }

    private static func buildSection(title: String, entries: [(String, String)]) -> InfoSection {
        // キーを整形して重複排除（属性と子要素の二重定義はまれ）
        var seen = Set<String>()
        var rows: [InfoRow] = []
        for (k, v) in entries {
            let key = humanKey(k)
            if seen.contains(key) { continue }
            seen.insert(key)
            rows.append(.keyValue(key: key, value: v))
        }
        return InfoSection(id: .xmp, title: title, rows: rows)
    }

    private static func humanKey(_ local: String) -> String {
        // "CreateDate" → "Create Date", "GTS_PDFXVersion" → "GTS PDFX Version"
        var result = ""
        for (i, ch) in local.enumerated() {
            if i > 0, ch.isUppercase, let prev = result.last, !prev.isUppercase, prev != " ", prev != "_" {
                result.append(" ")
            }
            if ch == "_" { result.append(" ") } else { result.append(ch) }
        }
        // 先頭のみ大文字化
        if let first = result.first {
            result = first.uppercased() + result.dropFirst()
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func splitQName(_ qname: String) -> (String, String) {
        if let idx = qname.firstIndex(of: ":") {
            return (String(qname[..<idx]), String(qname[qname.index(after: idx)...]))
        }
        return ("", qname)
    }

    /// RDF 構造 (Alt/Seq/Bag) から値を取り出す
    private static func extractValue(from el: XMLElement) -> String {
        let elementChildren = (el.children ?? []).compactMap { $0 as? XMLElement }
        if let container = elementChildren.first,
           let name = container.name {
            let (prefix, local) = splitQName(name)
            if prefix == "rdf", local == "Alt" || local == "Seq" || local == "Bag" {
                let items = (container.children ?? [])
                    .compactMap { $0 as? XMLElement }
                    .filter { li in
                        let (lp, ll) = splitQName(li.name ?? "")
                        return lp == "rdf" && ll == "li"
                    }
                let strings = items.compactMap { li -> String? in
                    let s = li.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return (s?.isEmpty ?? true) ? nil : s
                }
                return strings.joined(separator: ", ")
            }
        }
        return el.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
