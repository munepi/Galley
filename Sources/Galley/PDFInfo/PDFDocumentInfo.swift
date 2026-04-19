// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import Foundation

enum SectionID: String {
    case file
    case documentInfo
    case xmp
    case security
    case pages
    case fonts
    case features
}

struct InfoSection {
    let id: SectionID
    let title: String
    var rows: [InfoRow]
}

enum InfoRow {
    case keyValue(key: String, value: String)
    case longText(label: String, value: String)

    var searchHaystack: String {
        switch self {
        case .keyValue(let k, let v): return "\(k) \(v)"
        case .longText(let l, let v): return "\(l) \(v)"
        }
    }
}

struct PDFDocumentInfo {
    var sections: [InfoSection]

    static let empty = PDFDocumentInfo(sections: [])

    func filtered(by query: String) -> PDFDocumentInfo {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return self }
        let needle = q.lowercased()
        let filtered = sections.map { sec -> InfoSection in
            let rows = sec.rows.filter { $0.searchHaystack.lowercased().contains(needle) }
            return InfoSection(id: sec.id, title: sec.title, rows: rows)
        }
        return PDFDocumentInfo(sections: filtered)
    }
}
