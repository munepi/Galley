// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import Foundation
import PDFKit

/// CGPDFDocument から pdffonts 相当のフォント情報を抽出する。
/// PDFKit の PDFPage.fonts は Helvetica にフォールバックするため、低レベルAPI直叩きが必須。
enum CGPDFFontScanner {

    struct Font {
        let displayName: String         // "FWHFXO+HaranoAjiGothic-Bold"
        let baseName: String            // "HaranoAjiGothic-Bold" (subset prefix除去後)
        let subsetPrefix: String?       // "FWHFXO"
        let typeDisplay: String         // "Type 0 (CIDFontType2)", "Type 1" 等
        let subtype: String             // 生のSubtype値
        let encoding: String
        let isEmbedded: Bool
        let hasToUnicode: Bool
        let pages: [Int]                // 1-indexed, ソート済
    }

    static func scan(_ document: PDFDocument) -> [Font] {
        guard let cgDoc = document.documentRef else { return [] }
        var byKey: [String: Font] = [:]
        var pagesByKey: [String: Set<Int>] = [:]

        guard cgDoc.numberOfPages >= 1 else { return [] }
        for i in 1...cgDoc.numberOfPages {
            guard let page = cgDoc.page(at: i),
                  let pageDict = page.dictionary else { continue }
            var resourcesRef: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(pageDict, "Resources", &resourcesRef),
                  let resources = resourcesRef else { continue }
            var fontsRef: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(resources, "Font", &fontsRef),
                  let fonts = fontsRef else { continue }

            for font in extractFonts(from: fonts) {
                let key = "\(font.displayName)|\(font.subtype)"
                if byKey[key] == nil {
                    byKey[key] = font
                    pagesByKey[key] = []
                }
                pagesByKey[key]?.insert(i)
            }
        }

        return byKey.map { key, f in
            Font(
                displayName: f.displayName,
                baseName: f.baseName,
                subsetPrefix: f.subsetPrefix,
                typeDisplay: f.typeDisplay,
                subtype: f.subtype,
                encoding: f.encoding,
                isEmbedded: f.isEmbedded,
                hasToUnicode: f.hasToUnicode,
                pages: (pagesByKey[key] ?? []).sorted()
            )
        }
        .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    // MARK: - Internal

    private static func extractFonts(from fontResourcesDict: CGPDFDictionaryRef) -> [Font] {
        var out: [Font] = []
        withUnsafeMutablePointer(to: &out) { ptr in
            CGPDFDictionaryApplyFunction(fontResourcesDict, { (_, obj, info) in
                guard let info = info else { return }
                let outPtr = info.assumingMemoryBound(to: [Font].self)
                var fontDict: CGPDFDictionaryRef?
                guard CGPDFObjectGetValue(obj, .dictionary, &fontDict),
                      let fd = fontDict else { return }
                if let font = CGPDFFontScanner.parseFont(dict: fd) {
                    outPtr.pointee.append(font)
                }
            }, UnsafeMutableRawPointer(ptr))
        }
        return out
    }

    fileprivate static func parseFont(dict fontDict: CGPDFDictionaryRef) -> Font? {
        let baseFont = getName(fontDict, "BaseFont") ?? "(unnamed)"
        let subtype = getName(fontDict, "Subtype") ?? "(unknown)"

        let (prefix, bareName) = splitSubsetPrefix(baseFont)

        // Type0 は composite フォント。FontDescriptor は DescendantFonts[0] に載る
        var descriptorHost = fontDict
        var typeDisplay = subtype
        if subtype == "Type0" {
            var descendants: CGPDFArrayRef?
            if CGPDFDictionaryGetArray(fontDict, "DescendantFonts", &descendants),
               let arr = descendants, CGPDFArrayGetCount(arr) > 0 {
                var descObj: CGPDFObjectRef?
                if CGPDFArrayGetObject(arr, 0, &descObj), let d = descObj {
                    var descDict: CGPDFDictionaryRef?
                    if CGPDFObjectGetValue(d, .dictionary, &descDict), let dd = descDict {
                        descriptorHost = dd
                        if let descSubtype = getName(dd, "Subtype") {
                            typeDisplay = "Type 0 (\(descSubtype))"
                        }
                    }
                }
            }
        }

        let encoding = extractEncoding(fontDict)

        // Type3 は本体dictに CharProcs が載っているので常に埋め込み扱い
        let isEmbedded: Bool
        if subtype == "Type3" {
            isEmbedded = true
        } else {
            isEmbedded = isFontEmbedded(descriptorHost)
        }

        var toUnicodeStream: CGPDFStreamRef?
        let hasToUnicode = CGPDFDictionaryGetStream(fontDict, "ToUnicode", &toUnicodeStream)

        return Font(
            displayName: baseFont,
            baseName: bareName,
            subsetPrefix: prefix,
            typeDisplay: typeDisplay,
            subtype: subtype,
            encoding: encoding,
            isEmbedded: isEmbedded,
            hasToUnicode: hasToUnicode,
            pages: []
        )
    }

    private static func extractEncoding(_ fontDict: CGPDFDictionaryRef) -> String {
        if let name = getName(fontDict, "Encoding") {
            return name
        }
        var encDict: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(fontDict, "Encoding", &encDict), let ed = encDict {
            if let base = getName(ed, "BaseEncoding") {
                return "\(base) (custom)"
            }
            return "Custom"
        }
        return "—"
    }

    private static func isFontEmbedded(_ descriptorHost: CGPDFDictionaryRef) -> Bool {
        var descriptorRef: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(descriptorHost, "FontDescriptor", &descriptorRef),
              let descriptor = descriptorRef else {
            return false
        }
        var stream: CGPDFStreamRef?
        if CGPDFDictionaryGetStream(descriptor, "FontFile", &stream) { return true }
        if CGPDFDictionaryGetStream(descriptor, "FontFile2", &stream) { return true }
        if CGPDFDictionaryGetStream(descriptor, "FontFile3", &stream) { return true }
        return false
    }

    /// "ABCDEF+FontName" → ("ABCDEF", "FontName")
    private static func splitSubsetPrefix(_ s: String) -> (String?, String) {
        guard s.count > 7 else { return (nil, s) }
        let prefixEnd = s.index(s.startIndex, offsetBy: 6)
        let afterPlus = s.index(prefixEnd, offsetBy: 1)
        let prefix = String(s[..<prefixEnd])
        let plus = s[prefixEnd]
        guard plus == "+",
              prefix.count == 6,
              prefix.allSatisfy({ $0.isASCII && $0.isUppercase && $0.isLetter }) else {
            return (nil, s)
        }
        return (prefix, String(s[afterPlus...]))
    }

    private static func getName(_ dict: CGPDFDictionaryRef, _ key: String) -> String? {
        var namePtr: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dict, key, &namePtr), let p = namePtr else {
            return nil
        }
        return String(cString: p)
    }
}
