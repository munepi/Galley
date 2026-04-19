// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

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
