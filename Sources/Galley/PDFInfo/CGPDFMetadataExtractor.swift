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
import PDFKit

enum CGPDFMetadataExtractor {

    struct XMPResult {
        let xml: String?     // 取得できたXML（デコード失敗時 nil）
        let byteCount: Int   // 原バイト数（取得失敗時 0）
        let isPresent: Bool  // /Metadata stream が存在したか
    }

    /// PDFDocument の catalog `/Metadata` stream から XMP 生XMLを取得
    static func extract(from document: PDFDocument) -> XMPResult {
        guard let cgDoc = document.documentRef,
              let catalog = cgDoc.catalog else {
            return XMPResult(xml: nil, byteCount: 0, isPresent: false)
        }
        var stream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(catalog, "Metadata", &stream),
              let s = stream else {
            return XMPResult(xml: nil, byteCount: 0, isPresent: false)
        }
        var format: CGPDFDataFormat = .raw
        guard let cfData = CGPDFStreamCopyData(s, &format) else {
            return XMPResult(xml: nil, byteCount: 0, isPresent: true)
        }
        let data = cfData as Data
        let decoded = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        return XMPResult(xml: decoded, byteCount: data.count, isPresent: true)
    }
}
