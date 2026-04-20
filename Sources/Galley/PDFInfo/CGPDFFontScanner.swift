// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import Foundation
import PDFKit

/// CGPDFDocument から pdffonts 相当のフォント情報を抽出する。
/// PDFKit の PDFPage.fonts は Helvetica にフォールバックするため、低レベルAPI直叩きが必須。
///
/// ドキュメント全体を一度だけ走査し、以下を再帰的に辿る:
/// - 各ページの /Resources（直接 + /Pages ツリーの親から継承）
/// - Form XObject（例: InDesignの図版）の /Resources を再帰
/// - Tiling Pattern の /Resources を再帰
///
/// Resources 辞書のポインタ同一性でメモ化することで、複数ページから共有される
/// 継承 Resources や共有 XObject を重複走査しない。
enum CGPDFFontScanner {

    struct Font {
        let displayName: String
        let baseName: String
        let subsetPrefix: String?
        let typeDisplay: String
        let subtype: String
        let encoding: String
        let isEmbedded: Bool
        let hasToUnicode: Bool
    }

    static func scan(_ document: PDFDocument) -> [Font] {
        guard let cgDoc = document.documentRef else { return [] }
        guard cgDoc.numberOfPages >= 1 else { return [] }

        let state = ScanState()
        for i in 1...cgDoc.numberOfPages {
            guard let page = cgDoc.page(at: i),
                  let pageDict = page.dictionary else { continue }
            collectResourcesForPage(pageDict, state: state)
        }

        return state.fontsByKey.values
            .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    // MARK: - Scan state (document-wide)

    fileprivate final class ScanState {
        /// displayName|subtype → Font (ドキュメント全体で一意化)
        var fontsByKey: [String: Font] = [:]
        /// 訪問済み Resources 辞書（ポインタ同一性）
        var seenResources: Set<Int> = []
    }

    private static func identityKey(_ ptr: CGPDFDictionaryRef) -> Int {
        return unsafeBitCast(ptr, to: Int.self)
    }

    /// ページ辞書から開始し、親チェインを遡って /Resources を集める。
    /// /Resources 内の XObject / Pattern も再帰的に辿る。
    private static func collectResourcesForPage(_ pageDict: CGPDFDictionaryRef, state: ScanState) {
        var currentDict: CGPDFDictionaryRef? = pageDict
        while let dict = currentDict {
            var res: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(dict, "Resources", &res), let r = res {
                collectFromResources(r, state: state)
            }
            var parent: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(dict, "Parent", &parent) {
                currentDict = parent
            } else {
                currentDict = nil
            }
        }
    }

    fileprivate static func collectFromResources(_ resources: CGPDFDictionaryRef, state: ScanState) {
        let id = identityKey(resources)
        if state.seenResources.contains(id) { return }
        state.seenResources.insert(id)

        // /Font
        var fontsDict: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Font", &fontsDict), let fd = fontsDict {
            appendFonts(from: fd, state: state)
        }

        // /XObject (Form XObjectの内部 /Resources を再帰)
        var xoDict: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "XObject", &xoDict), let xd = xoDict {
            let ctx = Unmanaged.passUnretained(state).toOpaque()
            CGPDFDictionaryApplyFunction(xd, { (_, obj, info) in
                guard let info = info else { return }
                let st = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
                var stream: CGPDFStreamRef?
                guard CGPDFObjectGetValue(obj, .stream, &stream), let s = stream else { return }
                guard let streamDict = CGPDFStreamGetDictionary(s) else { return }
                // Subtype が "Form" でなければスキップ（Image は無関係）
                var subtypePtr: UnsafePointer<CChar>?
                guard CGPDFDictionaryGetName(streamDict, "Subtype", &subtypePtr),
                      let sp = subtypePtr,
                      String(cString: sp) == "Form" else { return }
                var res: CGPDFDictionaryRef?
                if CGPDFDictionaryGetDictionary(streamDict, "Resources", &res), let r = res {
                    CGPDFFontScanner.collectFromResources(r, state: st)
                }
            }, ctx)
        }

        // /Pattern (Tiling Pattern の /Resources を再帰)
        var patDict: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Pattern", &patDict), let pd = patDict {
            let ctx = Unmanaged.passUnretained(state).toOpaque()
            CGPDFDictionaryApplyFunction(pd, { (_, obj, info) in
                guard let info = info else { return }
                let st = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
                var stream: CGPDFStreamRef?
                if CGPDFObjectGetValue(obj, .stream, &stream), let s = stream,
                   let patternDict = CGPDFStreamGetDictionary(s) {
                    var res: CGPDFDictionaryRef?
                    if CGPDFDictionaryGetDictionary(patternDict, "Resources", &res), let r = res {
                        CGPDFFontScanner.collectFromResources(r, state: st)
                    }
                }
            }, ctx)
        }
    }

    // MARK: - Font dict parsing

    fileprivate static func appendFonts(from fontResourcesDict: CGPDFDictionaryRef, state: ScanState) {
        let ctx = Unmanaged.passUnretained(state).toOpaque()
        CGPDFDictionaryApplyFunction(fontResourcesDict, { (_, obj, info) in
            guard let info = info else { return }
            let st = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
            var fontDict: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(obj, .dictionary, &fontDict),
                  let fd = fontDict else { return }
            if let font = CGPDFFontScanner.parseFont(dict: fd) {
                let key = "\(font.displayName)|\(font.subtype)"
                if st.fontsByKey[key] == nil {
                    st.fontsByKey[key] = font
                }
            }
        }, ctx)
    }

    fileprivate static func parseFont(dict fontDict: CGPDFDictionaryRef) -> Font? {
        let baseFont = getName(fontDict, "BaseFont") ?? "(unnamed)"
        let subtype = getName(fontDict, "Subtype") ?? "(unknown)"

        let (prefix, bareName) = splitSubsetPrefix(baseFont)

        // Type0 は composite。FontDescriptor は DescendantFonts[0] に載る
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

        // Type3 は本体dictにCharProcsがインライン定義される（常に埋め込み扱い）
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
            hasToUnicode: hasToUnicode
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
