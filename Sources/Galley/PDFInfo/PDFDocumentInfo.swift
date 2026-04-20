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
