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
import CoreGraphics
import PDFKit

// ==========================================
// ページのコンテンツストリームを CGPDFScanner で走査し、描画された
// オブジェクト (パス・テキスト・画像・シェーディング) を「ページ座標での
// 形状 + その時点の色」として記録する。Color Picker のヒットテストに使う。
//
// 座標: PDFKit の page 座標は生の PDF user space と一致する (/Rotate や
// CropBox の原点は描画時にのみ適用される) ので、CTM を掛けたストリーム
// 座標をそのまま PDFView.convert(_:to: page) の点と比較できる。
//
// グリフ幅は計算しない。テキストは「表示演算子の原点と変換行列」だけを
// 記録し、ヒットテスト側で PDFKit の文字矩形と突き合わせる。
// ==========================================
enum CGPDFPageColorScanner {

    // MARK: - Recorded objects

    /// フォントの識別情報と、文字送りに必要な最小限のメトリクス。
    /// - simple font (Type1/TrueType/Type3): /FirstChar + /Widths (+ /MissingWidth)
    /// - Type0: /DescendantFonts[0] の /DW + /W。CID は Identity-* なら code そのもの、
    ///   埋め込み CMap なら cidrange/cidchar から、それ以外の定義済み CMap は不明 (DW を使う)
    final class FontInfo {
        let resourceName: String
        let subtype: String?
        let baseFont: String?
        var isVertical: Bool

        var isType0 = false
        var bytesPerCode = 1
        var identityCMap = false
        var cidMap: [Int: Int] = [:]          // 埋め込み CMap の code → CID
        var firstChar = 0
        var simpleWidths: [CGFloat] = []      // glyph space (÷1000 または FontMatrix)
        var missingWidth: CGFloat = 0
        var cidWidths: [Int: CGFloat] = [:]
        var defaultWidth: CGFloat = 1000
        var glyphScale: CGFloat = 0.001       // Type3 は FontMatrix.a
        var hasMetrics = false

        init(resourceName: String, subtype: String?, baseFont: String?, isVertical: Bool) {
            self.resourceName = resourceName
            self.subtype = subtype
            self.baseFont = baseFont
            self.isVertical = isVertical
        }

        /// 文字列バイト列を code 列に分解する
        func codes(in bytes: UnsafeBufferPointer<UInt8>) -> [Int] {
            if bytesPerCode <= 1 { return bytes.map { Int($0) } }
            var out: [Int] = []
            var i = 0
            while i < bytes.count {
                if i + 1 < bytes.count {
                    out.append(Int(bytes[i]) << 8 | Int(bytes[i + 1]))
                    i += 2
                } else {
                    out.append(Int(bytes[i]))
                    i += 1
                }
            }
            return out
        }

        /// テキスト空間での横幅 (w0)。メトリクスが無ければ nil。
        func width(forCode code: Int) -> CGFloat? {
            guard hasMetrics else { return nil }
            if isType0 {
                let cid: Int
                if identityCMap {
                    cid = code
                } else if let c = cidMap[code] {
                    cid = c
                } else {
                    return defaultWidth * glyphScale
                }
                return (cidWidths[cid] ?? defaultWidth) * glyphScale
            }
            let idx = code - firstChar
            if idx >= 0, idx < simpleWidths.count {
                return simpleWidths[idx] * glyphScale
            }
            return missingWidth * glyphScale
        }
    }

    struct PathObject {
        let isStroke: Bool
        let evenOdd: Bool
        let path: CGPath
        /// ページ座標での線幅 (stroke のみ)。0 は「最細」。
        let lineWidth: CGFloat
        let color: PDFPaintColor
        let alpha: CGFloat
        let blendMode: String?
        let clip: CGRect?
    }

    struct TextRun {
        /// テキスト空間 (1 単位 = 1 em) → ページ座標
        let matrix: CGAffineTransform
        let inverse: CGAffineTransform
        let origin: CGPoint
        let font: FontInfo?
        let fontSize: CGFloat
        /// ページ座標での実効フォントサイズ (Tfs × √|det(Tm×CTM)|)
        let effectiveSize: CGFloat
        /// run の長さ (matrix の単位 = 1 em 相当)。幅が分からなければ nil。
        let lengthInGlyphUnits: CGFloat?
        let fill: PDFPaintColor
        let stroke: PDFPaintColor
        let renderMode: Int
        let alpha: CGFloat
        let blendMode: String?
        let clip: CGRect?
    }

    struct ImageObject {
        let name: String?
        let bounds: CGPath
        let colorSpace: PDFColorSpaceInfo?
        let bitsPerComponent: Int?
        let isMask: Bool
        let isInline: Bool
        /// ImageMask のときの塗り色
        let fill: PDFPaintColor
        let alpha: CGFloat
        let clip: CGRect?
    }

    struct ShadingObject {
        let name: String
        let shadingType: Int?
        let colorSpace: PDFColorSpaceInfo?
        let clip: CGRect?
        let alpha: CGFloat
    }

    enum InkObject {
        case path(PathObject)
        case text(TextRun)
        case image(ImageObject)
        case shading(ShadingObject)
    }

    /// 走査結果 (描画順)。NSMapTable の値にするためクラス。
    final class ScanResult {
        var inks: [InkObject] = []
        var operatorCount = 0
        var completed = false
        var inlineImageOperators: [String] = []   // BI/ID/EI のどれが届いたか (診断用)
    }

    // MARK: - Graphics state

    struct GraphicsState {
        var ctm = CGAffineTransform.identity
        var fill = PDFPaintColor.initial
        var stroke = PDFPaintColor.initial
        var lineWidth: CGFloat = 1
        var clip: CGRect? = nil
        var fillAlpha: CGFloat = 1
        var strokeAlpha: CGFloat = 1
        var blendMode: String? = nil
        // text state
        var font: FontInfo? = nil
        var fontSize: CGFloat = 0
        var charSpacing: CGFloat = 0
        var wordSpacing: CGFloat = 0
        var hScale: CGFloat = 1
        var leading: CGFloat = 0
        var rise: CGFloat = 0
        var renderMode: Int = 0

        mutating func intersectClip(_ rect: CGRect) {
            if let c = clip {
                clip = c.intersection(rect)
            } else {
                clip = rect
            }
        }
    }

    // MARK: - Entry point

    static func scan(_ page: PDFPage) -> ScanResult? {
        guard let pageRef = page.pageRef else { return nil }
        guard let table = operatorTable else { return nil }

        let cs = CGPDFContentStreamCreateWithPage(pageRef)
        defer { CGPDFContentStreamRelease(cs) }

        let state = ScanState(table: table)
        let info = Unmanaged.passUnretained(state).toOpaque()
        let scanner = CGPDFScannerCreate(cs, table, info)
        defer { CGPDFScannerRelease(scanner) }

        let t0 = CFAbsoluteTimeGetCurrent()
        state.result.completed = CGPDFScannerScan(scanner)
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000

        let r = state.result
        var paths = 0, texts = 0, images = 0, shadings = 0
        for ink in r.inks {
            switch ink {
            case .path: paths += 1
            case .text: texts += 1
            case .image: images += 1
            case .shading: shadings += 1
            }
        }
        Log.colorPicker.info("scan: ops=\(r.operatorCount) paths=\(paths) texts=\(texts) images=\(images) shadings=\(shadings) inline=\(r.inlineImageOperators.joined(separator: ","), privacy: .public) completed=\(r.completed) \(String(format: "%.1f", ms), privacy: .public)ms")
        return r
    }

    // MARK: - Operator table (shared; callbacks are static and capture nothing)

    private static let operatorTable: CGPDFOperatorTableRef? = {
        guard let table = CGPDFOperatorTableCreate() else { return nil }
        typealias CB = @convention(c) (CGPDFScannerRef, UnsafeMutableRawPointer?) -> Void
        func set(_ name: String, _ cb: CB) {
            CGPDFOperatorTableSetCallback(table, name, cb)
        }

        // Graphics state
        set("q")  { s, i in ScanState.from(i)?.opSave(s) }
        set("Q")  { s, i in ScanState.from(i)?.opRestore(s) }
        set("cm") { s, i in ScanState.from(i)?.opConcat(s) }
        set("w")  { s, i in ScanState.from(i)?.opLineWidth(s) }
        set("gs") { s, i in ScanState.from(i)?.opExtGState(s) }

        // Path construction
        set("m")  { s, i in ScanState.from(i)?.opMoveTo(s) }
        set("l")  { s, i in ScanState.from(i)?.opLineTo(s) }
        set("c")  { s, i in ScanState.from(i)?.opCurve(s, kind: 0) }
        set("v")  { s, i in ScanState.from(i)?.opCurve(s, kind: 1) }
        set("y")  { s, i in ScanState.from(i)?.opCurve(s, kind: 2) }
        set("h")  { s, i in ScanState.from(i)?.opClose(s) }
        set("re") { s, i in ScanState.from(i)?.opRect(s) }

        // Path painting
        set("S")  { s, i in ScanState.from(i)?.opPaint(s, close: false, fill: false, evenOdd: false, stroke: true) }
        set("s")  { s, i in ScanState.from(i)?.opPaint(s, close: true,  fill: false, evenOdd: false, stroke: true) }
        set("f")  { s, i in ScanState.from(i)?.opPaint(s, close: false, fill: true,  evenOdd: false, stroke: false) }
        set("F")  { s, i in ScanState.from(i)?.opPaint(s, close: false, fill: true,  evenOdd: false, stroke: false) }
        set("f*") { s, i in ScanState.from(i)?.opPaint(s, close: false, fill: true,  evenOdd: true,  stroke: false) }
        set("B")  { s, i in ScanState.from(i)?.opPaint(s, close: false, fill: true,  evenOdd: false, stroke: true) }
        set("B*") { s, i in ScanState.from(i)?.opPaint(s, close: false, fill: true,  evenOdd: true,  stroke: true) }
        set("b")  { s, i in ScanState.from(i)?.opPaint(s, close: true,  fill: true,  evenOdd: false, stroke: true) }
        set("b*") { s, i in ScanState.from(i)?.opPaint(s, close: true,  fill: true,  evenOdd: true,  stroke: true) }
        set("n")  { s, i in ScanState.from(i)?.opPaint(s, close: false, fill: false, evenOdd: false, stroke: false) }
        set("W")  { s, i in ScanState.from(i)?.opClip(s, evenOdd: false) }
        set("W*") { s, i in ScanState.from(i)?.opClip(s, evenOdd: true) }

        // Color
        set("g")   { s, i in ScanState.from(i)?.opDeviceColor(s, space: .deviceGray, stroke: false) }
        set("G")   { s, i in ScanState.from(i)?.opDeviceColor(s, space: .deviceGray, stroke: true) }
        set("rg")  { s, i in ScanState.from(i)?.opDeviceColor(s, space: .deviceRGB, stroke: false) }
        set("RG")  { s, i in ScanState.from(i)?.opDeviceColor(s, space: .deviceRGB, stroke: true) }
        set("k")   { s, i in ScanState.from(i)?.opDeviceColor(s, space: .deviceCMYK, stroke: false) }
        set("K")   { s, i in ScanState.from(i)?.opDeviceColor(s, space: .deviceCMYK, stroke: true) }
        set("cs")  { s, i in ScanState.from(i)?.opColorSpace(s, stroke: false) }
        set("CS")  { s, i in ScanState.from(i)?.opColorSpace(s, stroke: true) }
        set("sc")  { s, i in ScanState.from(i)?.opSetColor(s, stroke: false) }
        set("scn") { s, i in ScanState.from(i)?.opSetColor(s, stroke: false) }
        set("SC")  { s, i in ScanState.from(i)?.opSetColor(s, stroke: true) }
        set("SCN") { s, i in ScanState.from(i)?.opSetColor(s, stroke: true) }

        // Text
        set("BT") { s, i in ScanState.from(i)?.opBeginText(s) }
        set("ET") { s, i in ScanState.from(i)?.opEndText(s) }
        set("Tf") { s, i in ScanState.from(i)?.opSetFont(s) }
        set("Td") { s, i in ScanState.from(i)?.opTextMove(s, setLeading: false) }
        set("TD") { s, i in ScanState.from(i)?.opTextMove(s, setLeading: true) }
        set("Tm") { s, i in ScanState.from(i)?.opTextMatrix(s) }
        set("T*") { s, i in ScanState.from(i)?.opNextLine(s) }
        set("TL") { s, i in ScanState.from(i)?.opTextNumber(s, key: 0) }
        set("Tc") { s, i in ScanState.from(i)?.opTextNumber(s, key: 1) }
        set("Tw") { s, i in ScanState.from(i)?.opTextNumber(s, key: 2) }
        set("Tz") { s, i in ScanState.from(i)?.opTextNumber(s, key: 3) }
        set("Ts") { s, i in ScanState.from(i)?.opTextNumber(s, key: 4) }
        set("Tr") { s, i in ScanState.from(i)?.opTextNumber(s, key: 5) }
        set("Tj") { s, i in ScanState.from(i)?.opShowText(s, mode: 0) }
        set("TJ") { s, i in ScanState.from(i)?.opShowText(s, mode: 0) }
        set("'")  { s, i in ScanState.from(i)?.opShowText(s, mode: 1) }
        set("\"") { s, i in ScanState.from(i)?.opShowText(s, mode: 2) }

        // XObjects, inline images, shadings
        set("Do") { s, i in ScanState.from(i)?.opXObject(s) }
        set("BI") { s, i in ScanState.from(i)?.opInlineImage(s, op: "BI") }
        set("ID") { s, i in ScanState.from(i)?.opInlineImage(s, op: "ID") }
        set("EI") { s, i in ScanState.from(i)?.opInlineImage(s, op: "EI") }
        set("sh") { s, i in ScanState.from(i)?.opShading(s) }

        return table
    }()

    // MARK: - Scan state

    fileprivate final class ScanState {
        let table: CGPDFOperatorTableRef
        let result = ScanResult()

        var gs = GraphicsState()
        var stack: [GraphicsState] = []
        var path = CGMutablePath()
        /// W / W* の後、次の描画演算子で適用する (true = even-odd)
        var pendingClip: Bool? = nil
        var textMatrix = CGAffineTransform.identity
        var lineMatrix = CGAffineTransform.identity

        var formDepth = 0
        var formsOnPath = Set<Int>()
        /// フォント辞書のポインタ → FontInfo (同一走査内でのメモ化)
        var fontCache: [Int: FontInfo] = [:]

        init(table: CGPDFOperatorTableRef) {
            self.table = table
        }

        static func from(_ info: UnsafeMutableRawPointer?) -> ScanState? {
            guard let info = info else { return nil }
            return Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
        }

        // MARK: Operand helpers

        /// スタック上の operand を全部取り出して元の順に返す
        func operands(_ s: CGPDFScannerRef) -> [CGPDFObjectRef] {
            var out: [CGPDFObjectRef] = []
            var obj: CGPDFObjectRef?
            while CGPDFScannerPopObject(s, &obj), let o = obj {
                out.append(o)
                obj = nil
            }
            return out.reversed()
        }

        func number(_ o: CGPDFObjectRef) -> CGFloat? {
            var r: CGPDFReal = 0
            if CGPDFObjectGetValue(o, .real, &r) { return r }
            var i: CGPDFInteger = 0
            if CGPDFObjectGetValue(o, .integer, &i) { return CGFloat(i) }
            return nil
        }

        func name(_ o: CGPDFObjectRef) -> String? {
            var p: UnsafePointer<CChar>?
            guard CGPDFObjectGetValue(o, .name, &p), let cp = p else { return nil }
            return String(cString: cp)
        }

        func numbers(_ s: CGPDFScannerRef) -> [CGFloat] {
            return operands(s).compactMap { number($0) }
        }

        func tick() {
            result.operatorCount += 1
        }

        var currentCTMScale: CGFloat {
            let m = gs.ctm
            return sqrt(abs(m.a * m.d - m.b * m.c))
        }

        // MARK: Graphics state ops

        func opSave(_ s: CGPDFScannerRef) {
            tick()
            _ = operands(s)
            stack.append(gs)
        }

        func opRestore(_ s: CGPDFScannerRef) {
            tick()
            _ = operands(s)
            if let g = stack.popLast() { gs = g }
        }

        func opConcat(_ s: CGPDFScannerRef) {
            tick()
            let n = numbers(s)
            guard n.count == 6 else { return }
            let m = CGAffineTransform(a: n[0], b: n[1], c: n[2], d: n[3], tx: n[4], ty: n[5])
            gs.ctm = m.concatenating(gs.ctm)
        }

        func opLineWidth(_ s: CGPDFScannerRef) {
            tick()
            if let w = numbers(s).last { gs.lineWidth = w }
        }

        func opExtGState(_ s: CGPDFScannerRef) {
            tick()
            guard let nameObj = operands(s).last, let n = name(nameObj) else { return }
            let cs = CGPDFScannerGetContentStream(s)
            guard let obj = CGPDFContentStreamGetResource(cs, "ExtGState", n) else { return }
            var dict: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(obj, .dictionary, &dict), let d = dict else { return }
            if let ca = CGPDFHelpers.number(d, "ca") { gs.fillAlpha = ca }
            if let CA = CGPDFHelpers.number(d, "CA") { gs.strokeAlpha = CA }
            if let lw = CGPDFHelpers.number(d, "LW") { gs.lineWidth = lw }
            if let bm = CGPDFHelpers.name(d, "BM") {
                gs.blendMode = (bm == "Normal" || bm == "Compatible") ? nil : bm
            } else {
                var arr: CGPDFArrayRef?
                if CGPDFDictionaryGetArray(d, "BM", &arr), let a = arr, CGPDFArrayGetCount(a) > 0 {
                    var p: UnsafePointer<CChar>?
                    if CGPDFArrayGetName(a, 0, &p), let cp = p {
                        let bm = String(cString: cp)
                        gs.blendMode = (bm == "Normal" || bm == "Compatible") ? nil : bm
                    }
                }
            }
        }

        // MARK: Path construction

        func opMoveTo(_ s: CGPDFScannerRef) {
            tick()
            let n = numbers(s)
            guard n.count >= 2 else { return }
            path.move(to: CGPoint(x: n[0], y: n[1]).applying(gs.ctm))
        }

        func opLineTo(_ s: CGPDFScannerRef) {
            tick()
            let n = numbers(s)
            guard n.count >= 2 else { return }
            let p = CGPoint(x: n[0], y: n[1]).applying(gs.ctm)
            if path.isEmpty { path.move(to: p) } else { path.addLine(to: p) }
        }

        /// kind 0 = c (x1 y1 x2 y2 x3 y3), 1 = v (x2 y2 x3 y3), 2 = y (x1 y1 x3 y3)
        func opCurve(_ s: CGPDFScannerRef, kind: Int) {
            tick()
            let n = numbers(s)
            let m = gs.ctm
            switch kind {
            case 0:
                guard n.count >= 6 else { return }
                let p1 = CGPoint(x: n[0], y: n[1]).applying(m)
                let p2 = CGPoint(x: n[2], y: n[3]).applying(m)
                let p3 = CGPoint(x: n[4], y: n[5]).applying(m)
                if path.isEmpty { path.move(to: p1) }
                path.addCurve(to: p3, control1: p1, control2: p2)
            case 1:
                guard n.count >= 4 else { return }
                let p2 = CGPoint(x: n[0], y: n[1]).applying(m)
                let p3 = CGPoint(x: n[2], y: n[3]).applying(m)
                if path.isEmpty { path.move(to: p2) }
                let p1 = path.currentPoint
                path.addCurve(to: p3, control1: p1, control2: p2)
            default:
                guard n.count >= 4 else { return }
                let p1 = CGPoint(x: n[0], y: n[1]).applying(m)
                let p3 = CGPoint(x: n[2], y: n[3]).applying(m)
                if path.isEmpty { path.move(to: p1) }
                path.addCurve(to: p3, control1: p1, control2: p3)
            }
        }

        func opClose(_ s: CGPDFScannerRef) {
            tick()
            _ = operands(s)
            if !path.isEmpty { path.closeSubpath() }
        }

        func opRect(_ s: CGPDFScannerRef) {
            tick()
            let n = numbers(s)
            guard n.count >= 4 else { return }
            let rect = CGRect(x: n[0], y: n[1], width: n[2], height: n[3])
            path.addRect(rect, transform: gs.ctm)
        }

        // MARK: Path painting

        func opClip(_ s: CGPDFScannerRef, evenOdd: Bool) {
            tick()
            _ = operands(s)
            pendingClip = evenOdd
        }

        func opPaint(_ s: CGPDFScannerRef, close: Bool, fill: Bool, evenOdd: Bool, stroke: Bool) {
            tick()
            _ = operands(s)
            if close, !path.isEmpty { path.closeSubpath() }

            if !path.isEmpty {
                if fill {
                    result.inks.append(.path(PathObject(
                        isStroke: false, evenOdd: evenOdd, path: path.copy() ?? path,
                        lineWidth: 0, color: gs.fill, alpha: gs.fillAlpha,
                        blendMode: gs.blendMode, clip: gs.clip)))
                }
                if stroke {
                    result.inks.append(.path(PathObject(
                        isStroke: true, evenOdd: false, path: path.copy() ?? path,
                        lineWidth: gs.lineWidth * currentCTMScale, color: gs.stroke,
                        alpha: gs.strokeAlpha, blendMode: gs.blendMode, clip: gs.clip)))
                }
            }

            if pendingClip != nil {
                // bbox 近似。空パスのクリップは何も描けない領域 (null rect) になる
                gs.intersectClip(path.isEmpty ? CGRect.null : path.boundingBoxOfPath)
                pendingClip = nil
            }
            path = CGMutablePath()
        }

        // MARK: Color ops

        func opDeviceColor(_ s: CGPDFScannerRef, space: PDFColorSpaceInfo, stroke: Bool) {
            tick()
            let n = numbers(s)
            let color = PDFPaintColor(space: space, components: n)
            if stroke { gs.stroke = color } else { gs.fill = color }
        }

        func opColorSpace(_ s: CGPDFScannerRef, stroke: Bool) {
            tick()
            guard let obj = operands(s).last else { return }
            let cs = CGPDFScannerGetContentStream(s)
            let space = PDFColorSpaceInfo.parse(obj, in: cs) ?? .unknown(name(obj) ?? "?")
            let color = PDFPaintColor(space: space, components: space.initialComponents)
            if stroke { gs.stroke = color } else { gs.fill = color }
        }

        func opSetColor(_ s: CGPDFScannerRef, stroke: Bool) {
            tick()
            let ops = operands(s)
            var comps: [CGFloat] = []
            var patternName: String? = nil
            for o in ops {
                if let v = number(o) {
                    comps.append(v)
                } else if let n = name(o) {
                    patternName = n
                }
            }
            var color = stroke ? gs.stroke : gs.fill
            color.components = comps
            color.patternName = patternName
            color.pattern = nil
            if let pn = patternName {
                color.pattern = resolvePattern(named: pn, scanner: s)
                if case .pattern = color.space {} else {
                    // cs /Pattern 無しで scn /P が来た (不正だが寛容に扱う)
                    color.space = .pattern(base: comps.isEmpty ? nil : color.space)
                }
            }
            if stroke { gs.stroke = color } else { gs.fill = color }
        }

        private func resolvePattern(named n: String, scanner s: CGPDFScannerRef) -> PDFPatternInfo? {
            let cs = CGPDFScannerGetContentStream(s)
            guard let obj = CGPDFContentStreamGetResource(cs, "Pattern", n) else { return nil }
            var dict: CGPDFDictionaryRef?
            var stream: CGPDFStreamRef?
            if CGPDFObjectGetValue(obj, .stream, &stream), let st = stream {
                dict = CGPDFStreamGetDictionary(st)
            } else {
                _ = CGPDFObjectGetValue(obj, .dictionary, &dict)
            }
            guard let d = dict else { return nil }
            let type = CGPDFHelpers.integer(d, "PatternType") ?? 1
            if type == 2 {
                var shadingObj: CGPDFObjectRef?
                var space: PDFColorSpaceInfo? = nil
                if CGPDFDictionaryGetObject(d, "Shading", &shadingObj), let so = shadingObj,
                   let sd = ScanState.dictionary(of: so) {
                    var csObj: CGPDFObjectRef?
                    if CGPDFDictionaryGetObject(sd, "ColorSpace", &csObj), let co = csObj {
                        space = PDFColorSpaceInfo.parse(co, in: cs)
                    }
                }
                return PDFPatternInfo(name: n, kind: .shading(colorSpace: space))
            }
            let paintType = CGPDFHelpers.integer(d, "PaintType") ?? 1
            return PDFPatternInfo(name: n, kind: .tiling(colored: paintType == 1))
        }

        static func dictionary(of obj: CGPDFObjectRef) -> CGPDFDictionaryRef? {
            var dict: CGPDFDictionaryRef?
            var stream: CGPDFStreamRef?
            if CGPDFObjectGetValue(obj, .stream, &stream), let st = stream {
                return CGPDFStreamGetDictionary(st)
            }
            if CGPDFObjectGetValue(obj, .dictionary, &dict) { return dict }
            return nil
        }

        // MARK: Text ops

        func opBeginText(_ s: CGPDFScannerRef) {
            tick()
            _ = operands(s)
            textMatrix = .identity
            lineMatrix = .identity
        }

        func opEndText(_ s: CGPDFScannerRef) {
            tick()
            _ = operands(s)
        }

        func opSetFont(_ s: CGPDFScannerRef) {
            tick()
            let ops = operands(s)
            var fontName: String? = nil
            var size: CGFloat? = nil
            for o in ops {
                if let n = name(o) { fontName = n }
                else if let v = number(o) { size = v }
            }
            if let sz = size { gs.fontSize = sz }
            guard let fn = fontName else { return }
            gs.font = resolveFont(named: fn, scanner: s)
        }

        private func resolveFont(named n: String, scanner s: CGPDFScannerRef) -> FontInfo {
            let cs = CGPDFScannerGetContentStream(s)
            guard let obj = CGPDFContentStreamGetResource(cs, "Font", n) else {
                return FontInfo(resourceName: n, subtype: nil, baseFont: nil, isVertical: false)
            }
            var dict: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(obj, .dictionary, &dict), let d = dict else {
                return FontInfo(resourceName: n, subtype: nil, baseFont: nil, isVertical: false)
            }
            let key = unsafeBitCast(d, to: Int.self)
            if let cached = fontCache[key] { return cached }

            let subtype = CGPDFHelpers.name(d, "Subtype")
            let baseFont = CGPDFHelpers.name(d, "BaseFont")
            var vertical = false
            var encodingName: String? = nil
            var encodingStream: CGPDFStreamRef? = nil
            if let enc = CGPDFHelpers.name(d, "Encoding") {
                encodingName = enc
                vertical = enc.hasSuffix("-V") || enc == "V"
            } else {
                var encStream: CGPDFStreamRef?
                if CGPDFDictionaryGetStream(d, "Encoding", &encStream), let es = encStream {
                    encodingStream = es
                    if let ed = CGPDFStreamGetDictionary(es) {
                        vertical = (CGPDFHelpers.integer(ed, "WMode") ?? 0) == 1
                    }
                }
            }
            let font = FontInfo(resourceName: n, subtype: subtype, baseFont: baseFont, isVertical: vertical)

            if subtype == "Type0" {
                font.isType0 = true
                font.bytesPerCode = 2
                if let en = encodingName, en.hasPrefix("Identity-") {
                    font.identityCMap = true
                } else if let es = encodingStream, let data = CGPDFHelpers.streamData(es) {
                    let parsed = CMapParser.parse(data)
                    font.bytesPerCode = parsed.bytesPerCode
                    font.cidMap = parsed.cidMap
                    if let wm = parsed.wmode { font.isVertical = font.isVertical || wm == 1 }
                }
                var descendants: CGPDFArrayRef?
                if CGPDFDictionaryGetArray(d, "DescendantFonts", &descendants), let arr = descendants,
                   CGPDFArrayGetCount(arr) > 0 {
                    var descDict: CGPDFDictionaryRef?
                    if CGPDFArrayGetDictionary(arr, 0, &descDict), let dd = descDict {
                        font.defaultWidth = CGPDFHelpers.number(dd, "DW") ?? 1000
                        var wArr: CGPDFArrayRef?
                        if CGPDFDictionaryGetArray(dd, "W", &wArr), let wa = wArr {
                            font.cidWidths = ScanState.parseCIDWidths(wa)
                        }
                        font.hasMetrics = true
                    }
                }
            } else {
                font.firstChar = CGPDFHelpers.integer(d, "FirstChar") ?? 0
                if let w = CGPDFHelpers.numberArray(d, "Widths") {
                    font.simpleWidths = w
                    font.hasMetrics = true
                }
                var descriptor: CGPDFDictionaryRef?
                if CGPDFDictionaryGetDictionary(d, "FontDescriptor", &descriptor), let fd = descriptor {
                    font.missingWidth = CGPDFHelpers.number(fd, "MissingWidth") ?? 0
                }
                if subtype == "Type3", let fm = CGPDFHelpers.numberArray(d, "FontMatrix"), fm.count == 6 {
                    font.glyphScale = fm[0]
                }
            }
            fontCache[key] = font
            return font
        }

        /// CIDFont の /W 配列: `c [w1 w2 …]` と `cfirst clast w` の 2 形式
        static func parseCIDWidths(_ arr: CGPDFArrayRef) -> [Int: CGFloat] {
            var widths: [Int: CGFloat] = [:]
            let count = CGPDFArrayGetCount(arr)
            var i = 0
            while i < count {
                var first: CGPDFReal = 0
                guard CGPDFArrayGetNumber(arr, i, &first) else { i += 1; continue }
                var sub: CGPDFArrayRef?
                if i + 1 < count, CGPDFArrayGetArray(arr, i + 1, &sub), let sa = sub {
                    let ws = CGPDFHelpers.numberArray(sa)
                    for (j, w) in ws.enumerated() {
                        widths[Int(first) + j] = w
                    }
                    i += 2
                } else if i + 2 < count {
                    var last: CGPDFReal = 0
                    var w: CGPDFReal = 0
                    if CGPDFArrayGetNumber(arr, i + 1, &last), CGPDFArrayGetNumber(arr, i + 2, &w) {
                        let lo = Int(first), hi = min(Int(last), lo + 65535)
                        if hi >= lo {
                            for cid in lo...hi { widths[cid] = w }
                        }
                    }
                    i += 3
                } else {
                    break
                }
            }
            return widths
        }

        func opTextMove(_ s: CGPDFScannerRef, setLeading: Bool) {
            tick()
            let n = numbers(s)
            guard n.count >= 2 else { return }
            if setLeading { gs.leading = -n[1] }
            moveTextLine(tx: n[0], ty: n[1])
        }

        private func moveTextLine(tx: CGFloat, ty: CGFloat) {
            lineMatrix = CGAffineTransform(translationX: tx, y: ty).concatenating(lineMatrix)
            textMatrix = lineMatrix
        }

        func opTextMatrix(_ s: CGPDFScannerRef) {
            tick()
            let n = numbers(s)
            guard n.count >= 6 else { return }
            lineMatrix = CGAffineTransform(a: n[0], b: n[1], c: n[2], d: n[3], tx: n[4], ty: n[5])
            textMatrix = lineMatrix
        }

        func opNextLine(_ s: CGPDFScannerRef) {
            tick()
            _ = operands(s)
            moveTextLine(tx: 0, ty: -gs.leading)
        }

        /// key: 0 TL, 1 Tc, 2 Tw, 3 Tz, 4 Ts, 5 Tr
        func opTextNumber(_ s: CGPDFScannerRef, key: Int) {
            tick()
            guard let v = numbers(s).last else { return }
            switch key {
            case 0: gs.leading = v
            case 1: gs.charSpacing = v
            case 2: gs.wordSpacing = v
            case 3: gs.hScale = v / 100
            case 4: gs.rise = v
            default: gs.renderMode = Int(v)
            }
        }

        /// mode 0 = Tj/TJ, 1 = ' , 2 = "
        func opShowText(_ s: CGPDFScannerRef, mode: Int) {
            tick()
            let ops = operands(s)
            if mode == 2 {
                // aw ac string "
                let nums = ops.compactMap { number($0) }
                if nums.count >= 2 {
                    gs.wordSpacing = nums[0]
                    gs.charSpacing = nums[1]
                }
            }
            if mode != 0 {
                moveTextLine(tx: 0, ty: -gs.leading)
            }

            // 文字送り: 文字列と TJ の調整値からテキスト空間での進みを積算する
            var total: CGFloat = 0
            var known = gs.font?.hasMetrics ?? false
            for o in ops {
                var str: CGPDFStringRef?
                var arr: CGPDFArrayRef?
                if CGPDFObjectGetValue(o, .string, &str), let st = str {
                    if let a = advance(of: st) { total += a } else { known = false }
                } else if CGPDFObjectGetValue(o, .array, &arr), let a = arr {
                    for i in 0..<CGPDFArrayGetCount(a) {
                        var el: CGPDFObjectRef?
                        guard CGPDFArrayGetObject(a, i, &el), let e = el else { continue }
                        var es: CGPDFStringRef?
                        if CGPDFObjectGetValue(e, .string, &es), let st = es {
                            if let adv = advance(of: st) { total += adv } else { known = false }
                        } else if let adj = number(e) {
                            // 横書き: tx = -adj/1000 × Tfs × Th、縦書き: ty = -adj/1000 × Tfs
                            let d = -adj / 1000 * gs.fontSize
                            total += (gs.font?.isVertical == true) ? d : d * gs.hScale
                        }
                    }
                }
            }

            recordTextRun(advance: total, known: known)

            if gs.font?.isVertical == true {
                textMatrix = CGAffineTransform(translationX: 0, y: total).concatenating(textMatrix)
            } else {
                textMatrix = CGAffineTransform(translationX: total, y: 0).concatenating(textMatrix)
            }
        }

        /// 1 文字列ぶんの進み (テキスト空間)。幅が不明なら nil。
        private func advance(of string: CGPDFStringRef) -> CGFloat? {
            guard let font = gs.font, font.hasMetrics,
                  let ptr = CGPDFStringGetBytePtr(string) else { return nil }
            let bytes = UnsafeBufferPointer(start: ptr, count: CGPDFStringGetLength(string))
            var total: CGFloat = 0
            for code in font.codes(in: bytes) {
                let isSpace = (font.bytesPerCode == 1 && code == 32)
                if font.isVertical {
                    // w1 は DW2 の既定 (-1000/1000)。/W2 は読まない
                    total += -1.0 * gs.fontSize + gs.charSpacing + (isSpace ? gs.wordSpacing : 0)
                } else {
                    guard let w0 = font.width(forCode: code) else { return nil }
                    total += (w0 * gs.fontSize + gs.charSpacing + (isSpace ? gs.wordSpacing : 0)) * gs.hScale
                }
            }
            return total
        }

        private func recordTextRun(advance: CGFloat, known: Bool) {
            let tm = textMatrix.concatenating(gs.ctm)
            let trm = CGAffineTransform(a: gs.fontSize * gs.hScale, b: 0, c: 0, d: gs.fontSize, tx: 0, ty: gs.rise)
                .concatenating(tm)
            let det = trm.a * trm.d - trm.b * trm.c
            guard abs(det) > 1e-12 else { return }
            let effective = gs.fontSize * sqrt(abs(tm.a * tm.d - tm.b * tm.c))
            var length: CGFloat? = nil
            if known {
                if gs.font?.isVertical == true {
                    length = gs.fontSize != 0 ? advance / gs.fontSize : nil
                } else {
                    let unit = gs.fontSize * gs.hScale
                    length = unit != 0 ? advance / unit : nil
                }
            }
            result.inks.append(.text(TextRun(
                matrix: trm, inverse: trm.inverted(),
                origin: CGPoint.zero.applying(trm),
                font: gs.font, fontSize: gs.fontSize, effectiveSize: effective,
                lengthInGlyphUnits: length,
                fill: gs.fill, stroke: gs.stroke, renderMode: gs.renderMode,
                alpha: gs.fillAlpha, blendMode: gs.blendMode, clip: gs.clip)))
        }

        // MARK: XObjects / inline images / shadings

        func opXObject(_ s: CGPDFScannerRef) {
            tick()
            guard let nameObj = operands(s).last, let n = name(nameObj) else { return }
            let cs = CGPDFScannerGetContentStream(s)
            guard let obj = CGPDFContentStreamGetResource(cs, "XObject", n) else { return }
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(obj, .stream, &stream), let st = stream,
                  let dict = CGPDFStreamGetDictionary(st) else { return }
            let subtype = CGPDFHelpers.name(dict, "Subtype") ?? ""
            if subtype == "Image" {
                recordImage(dict: dict, name: n, inline: false, contentStream: cs)
            } else if subtype == "Form" {
                recurseForm(stream: st, dict: dict, parent: cs)
            }
        }

        func opInlineImage(_ s: CGPDFScannerRef, op: String) {
            tick()
            if !result.inlineImageOperators.contains(op) {
                result.inlineImageOperators.append(op)
            }
            // CoreGraphics は BI…ID…EI を内部で読み、画像ストリームを "EI" の operand として渡す
            let ops = operands(s)
            for o in ops {
                var stream: CGPDFStreamRef?
                if CGPDFObjectGetValue(o, .stream, &stream), let st = stream,
                   let dict = CGPDFStreamGetDictionary(st) {
                    recordImage(dict: dict, name: nil, inline: true, contentStream: CGPDFScannerGetContentStream(s))
                }
            }
        }

        private func recordImage(dict: CGPDFDictionaryRef, name: String?, inline: Bool, contentStream: CGPDFContentStreamRef) {
            var space: PDFColorSpaceInfo? = nil
            var csObj: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dict, "ColorSpace", &csObj) || CGPDFDictionaryGetObject(dict, "CS", &csObj),
               let co = csObj {
                space = PDFColorSpaceInfo.parse(co, in: contentStream)
            }
            let bpc = CGPDFHelpers.integer(dict, "BitsPerComponent") ?? CGPDFHelpers.integer(dict, "BPC")
            let isMask = (CGPDFHelpers.bool(dict, "ImageMask") ?? CGPDFHelpers.bool(dict, "IM")) ?? false
            var m = gs.ctm
            let bounds = CGPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1), transform: &m)
            result.inks.append(.image(ImageObject(
                name: name, bounds: bounds, colorSpace: space, bitsPerComponent: bpc,
                isMask: isMask, isInline: inline, fill: gs.fill, alpha: gs.fillAlpha, clip: gs.clip)))
        }

        private func recurseForm(stream: CGPDFStreamRef, dict: CGPDFDictionaryRef, parent: CGPDFContentStreamRef) {
            let id = unsafeBitCast(stream, to: Int.self)
            guard formDepth < 12, !formsOnPath.contains(id) else { return }
            formDepth += 1
            formsOnPath.insert(id)
            defer {
                formDepth -= 1
                formsOnPath.remove(id)
            }

            let savedStack = stack
            let savedGS = gs
            let savedPath = path
            let savedPendingClip = pendingClip
            let savedTextMatrix = textMatrix
            let savedLineMatrix = lineMatrix

            if let m = CGPDFHelpers.numberArray(dict, "Matrix"), m.count == 6 {
                gs.ctm = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5]).concatenating(gs.ctm)
            }
            if let b = CGPDFHelpers.numberArray(dict, "BBox"), b.count == 4 {
                let rect = CGRect(x: min(b[0], b[2]), y: min(b[1], b[3]),
                                  width: abs(b[2] - b[0]), height: abs(b[3] - b[1]))
                var m = gs.ctm
                gs.intersectClip(CGPath(rect: rect, transform: &m).boundingBoxOfPath)
            }
            path = CGMutablePath()
            pendingClip = nil

            var resources: CGPDFDictionaryRef?
            _ = CGPDFDictionaryGetDictionary(dict, "Resources", &resources)
            let child = CGPDFContentStreamCreateWithStream(stream, resources ?? dict, parent)
            let info = Unmanaged.passUnretained(self).toOpaque()
            let scanner = CGPDFScannerCreate(child, table, info)
            _ = CGPDFScannerScan(scanner)
            CGPDFScannerRelease(scanner)
            CGPDFContentStreamRelease(child)

            stack = savedStack
            gs = savedGS
            path = savedPath
            pendingClip = savedPendingClip
            textMatrix = savedTextMatrix
            lineMatrix = savedLineMatrix
        }

        func opShading(_ s: CGPDFScannerRef) {
            tick()
            guard let nameObj = operands(s).last, let n = name(nameObj) else { return }
            let cs = CGPDFScannerGetContentStream(s)
            var shadingType: Int? = nil
            var space: PDFColorSpaceInfo? = nil
            if let obj = CGPDFContentStreamGetResource(cs, "Shading", n), let d = ScanState.dictionary(of: obj) {
                shadingType = CGPDFHelpers.integer(d, "ShadingType")
                var csObj: CGPDFObjectRef?
                if CGPDFDictionaryGetObject(d, "ColorSpace", &csObj), let co = csObj {
                    space = PDFColorSpaceInfo.parse(co, in: cs)
                }
            }
            result.inks.append(.shading(ShadingObject(
                name: n, shadingType: shadingType, colorSpace: space, clip: gs.clip, alpha: gs.fillAlpha)))
        }
    }
}

// ==========================================
// 埋め込み CMap の最小パーサ (codespacerange の長さと cidrange/cidchar)
// ==========================================
enum CMapParser {
    struct Result {
        var bytesPerCode = 2
        var cidMap: [Int: Int] = [:]
        var wmode: Int? = nil
    }

    static func parse(_ data: Data) -> Result {
        var result = Result()
        guard let text = String(data: data, encoding: .isoLatin1) else { return result }

        // トークン化: <hex>, 数値, キーワード
        var tokens: [String] = []
        var current = ""
        var inHex = false
        var inComment = false
        for ch in text {
            if inComment {
                if ch == "\n" || ch == "\r" { inComment = false }
                continue
            }
            if inHex {
                if ch == ">" {
                    tokens.append("<" + current + ">")
                    current = ""
                    inHex = false
                } else if !ch.isWhitespace {
                    current.append(ch)
                }
                continue
            }
            if ch == "<" {
                if !current.isEmpty { tokens.append(current); current = "" }
                inHex = true
            } else if ch == "%" {
                if !current.isEmpty { tokens.append(current); current = "" }
                inComment = true
            } else if ch.isWhitespace || ch == "[" || ch == "]" || ch == "{" || ch == "}" {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }

        func hexValue(_ t: String) -> (value: Int, bytes: Int)? {
            guard t.hasPrefix("<"), t.hasSuffix(">") else { return nil }
            let body = t.dropFirst().dropLast()
            guard let v = Int(body, radix: 16) else { return nil }
            return (v, max(1, (body.count + 1) / 2))
        }

        var i = 0
        var sawCodespace = false
        while i < tokens.count {
            let t = tokens[i]
            switch t {
            case "/WMode":
                if i + 1 < tokens.count, let v = Int(tokens[i + 1]) { result.wmode = v }
                i += 2
            case "begincodespacerange":
                i += 1
                while i + 1 < tokens.count, tokens[i] != "endcodespacerange" {
                    if let lo = hexValue(tokens[i]), !sawCodespace {
                        result.bytesPerCode = lo.bytes
                        sawCodespace = true
                    }
                    i += 2
                }
            case "begincidrange":
                i += 1
                while i + 2 < tokens.count, tokens[i] != "endcidrange" {
                    if let lo = hexValue(tokens[i]), let hi = hexValue(tokens[i + 1]), let cid = Int(tokens[i + 2]) {
                        let span = min(hi.value - lo.value, 65535)
                        if span >= 0 {
                            for k in 0...span { result.cidMap[lo.value + k] = cid + k }
                        }
                    }
                    i += 3
                }
            case "begincidchar":
                i += 1
                while i + 1 < tokens.count, tokens[i] != "endcidchar" {
                    if let code = hexValue(tokens[i]), let cid = Int(tokens[i + 1]) {
                        result.cidMap[code.value] = cid
                    }
                    i += 2
                }
            default:
                i += 1
            }
        }
        return result
    }
}
