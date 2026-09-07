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

// ==========================================
// 「Copy Color as PDF」: 拾った色で塗った小さな矩形を、色空間定義ごと
// ベクタ PDF として書き出す。Illustrator などに貼ると DeviceCMYK の生値や
// Separation (特色) がそのまま渡る。
//
// CGPDFContext はデバイス色空間を ICCBased に変換してしまうので、
// PDF は自前で組み立てる (オブジェクト数個の最小構成、無圧縮)。
// ==========================================
enum PDFColorSwatchWriter {

    /// 書き出す矩形の一辺 (pt)。Digital Color Meter の画像コピーと同じ感覚の
    /// 小さな色見本。貼り先で選びやすいよう 64 pt 四方にしている。
    static let swatchSize: CGFloat = 64

    /// 書き出しに使う色と、近似した場合の注記
    struct Prepared {
        let color: PDFPaintColor
        let note: String?
    }

    /// 生値のまま書けない色空間を、書ける形に寄せる。
    /// - Indexed → base 色空間の値
    /// - Pattern (uncolored) → base 色空間の値。colored / shading は書けない (nil)
    /// - CalRGB / CalGray → DeviceRGB / DeviceGray (注記つき)
    /// - Separation / DeviceN で tint 関数が無いもの → 代替色空間の値 (注記つき)
    static func prepare(_ color: PDFPaintColor) -> Prepared? {
        switch color.space {
        case .indexed:
            guard let resolved = color.resolvedIndexedColor else { return nil }
            return prepare(resolved)
        case .pattern(let base):
            guard let b = base, !color.components.isEmpty else { return nil }
            return prepare(PDFPaintColor(space: b, components: color.components))
        case .calRGB:
            return Prepared(color: PDFPaintColor(space: .deviceRGB, components: color.components),
                            note: "CalRGB written as DeviceRGB")
        case .calGray:
            return Prepared(color: PDFPaintColor(space: .deviceGray, components: color.components),
                            note: "CalGray written as DeviceGray")
        case .separation(_, _, let fn), .deviceN(_, _, let fn):
            if fn == nil, let alt = color.alternateColor {
                return Prepared(color: alt, note: "no tint transform; written in the alternate space")
            }
            return Prepared(color: color, note: nil)
        case .unknown:
            return nil
        case .iccBased(let n, let alternate, let iccData):
            if iccData == nil {
                if let alt = alternate {
                    return Prepared(color: PDFPaintColor(space: alt, components: color.components),
                                    note: "ICC profile unavailable; written in the alternate space")
                }
                let device: PDFColorSpaceInfo
                switch n {
                case 1: device = .deviceGray
                case 4: device = .deviceCMYK
                default: device = .deviceRGB
                }
                return Prepared(color: PDFPaintColor(space: device, components: color.components),
                                note: "ICC profile unavailable; written as \(device.displayName)")
            }
            return Prepared(color: color, note: nil)
        default:
            return Prepared(color: color, note: nil)
        }
    }

    /// 1 ページ・1 矩形の PDF を返す。書けない色空間なら nil。
    static func pdfData(for color: PDFPaintColor, size: CGFloat = swatchSize) -> Data? {
        guard let prepared = prepare(color) else { return nil }
        let c = prepared.color
        guard c.components.count == c.space.componentCount || c.space.componentCount == 0 else { return nil }

        var builder = Builder()
        let csRef = builder.colorSpace(c.space)

        // 描画: デバイス色空間は専用演算子、それ以外は cs/scn
        var ops = "q\n"
        let comps = c.components.map(Builder.num).joined(separator: " ")
        switch c.space {
        case .deviceGray: ops += "\(comps) g\n"
        case .deviceRGB:  ops += "\(comps) rg\n"
        case .deviceCMYK: ops += "\(comps) k\n"
        default:          ops += "/CS0 cs \(comps) scn\n"
        }
        ops += "0 0 \(Builder.num(size)) \(Builder.num(size)) re f\nQ\n"
        let content = builder.addStream(dict: "", data: Data(ops.utf8))

        var resources = "<< >>"
        if let ref = csRef {
            resources = "<< /ColorSpace << /CS0 \(ref) >> >>"
        }
        let pagesNum = builder.reserve()
        let page = builder.add("<< /Type /Page /Parent \(pagesNum) 0 R /MediaBox [0 0 \(Builder.num(size)) \(Builder.num(size))] /Resources \(resources) /Contents \(content) 0 R >>")
        builder.set(pagesNum, "<< /Type /Pages /Kids [\(page) 0 R] /Count 1 >>")
        let catalog = builder.add("<< /Type /Catalog /Pages \(pagesNum) 0 R >>")
        let info = builder.add("<< /Producer (Galley Color Picker) >>")
        return builder.finish(root: catalog, info: info)
    }

    // MARK: - Minimal PDF object builder

    struct Builder {
        private var objects: [Data?] = []

        /// 番号だけ先に取る (Pages ↔ Page の相互参照用)
        mutating func reserve() -> Int {
            objects.append(nil)
            return objects.count
        }

        mutating func set(_ number: Int, _ body: String) {
            objects[number - 1] = Data(body.utf8)
        }

        @discardableResult
        mutating func add(_ body: String) -> Int {
            objects.append(Data(body.utf8))
            return objects.count
        }

        /// `dict` は `<<` `>>` を含まない追加エントリ (例: `/N 4 /Alternate /DeviceCMYK`)
        mutating func addStream(dict: String, data: Data) -> Int {
            var body = Data("<< /Length \(data.count) \(dict) >>\nstream\n".utf8)
            body.append(data)
            body.append(Data("\nendstream".utf8))
            objects.append(body)
            return objects.count
        }

        static func num(_ v: CGFloat) -> String {
            if v == v.rounded(), abs(v) < 1e9 { return String(Int(v)) }
            var s = String(format: "%.6f", v)
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
            return s
        }

        static func nums(_ vs: [CGFloat]) -> String {
            return "[" + vs.map(num).joined(separator: " ") + "]"
        }

        /// PDF 名前オブジェクト。空白・区切り文字・非 ASCII は #xx にエスケープ
        static func name(_ s: String) -> String {
            var out = "/"
            for b in s.utf8 {
                let c = Character(UnicodeScalar(b))
                let regular = b > 0x20 && b < 0x7F && !"#/%()<>[]{}".contains(c)
                if regular {
                    out.append(c)
                } else {
                    out += String(format: "#%02X", b)
                }
            }
            return out
        }

        /// 色空間を PDF オブジェクトとして書き、参照文字列 (名前・配列・`n 0 R`) を返す。
        /// デバイス色空間はリソース登録不要なので nil。
        mutating func colorSpace(_ space: PDFColorSpaceInfo) -> String? {
            switch space {
            case .deviceGray, .deviceRGB, .deviceCMYK, .calGray, .calRGB, .indexed, .pattern, .unknown:
                return nil
            default:
                return colorSpaceObject(space)
            }
        }

        private mutating func colorSpaceObject(_ space: PDFColorSpaceInfo) -> String {
            switch space {
            case .deviceGray, .calGray: return "/DeviceGray"
            case .deviceRGB, .calRGB: return "/DeviceRGB"
            case .deviceCMYK: return "/DeviceCMYK"
            case .lab(let range):
                return "[/Lab << /WhitePoint [0.9505 1 1.089] /Range \(Builder.nums(range)) >>]"
            case .iccBased(let n, let alternate, let iccData):
                guard let data = iccData else {
                    if let alt = alternate { return colorSpaceObject(alt) }
                    return n == 1 ? "/DeviceGray" : (n == 4 ? "/DeviceCMYK" : "/DeviceRGB")
                }
                var dict = "/N \(n)"
                if let alt = alternate {
                    dict += " /Alternate \(colorSpaceObject(alt))"
                }
                let ref = addStream(dict: dict, data: data)
                return "[/ICCBased \(ref) 0 R]"
            case .separation(let name, let alternate, let fn):
                let alt = colorSpaceObject(alternate)
                let f = fn.map { function($0) } ?? identityTint(for: alternate)
                return "[/Separation \(Builder.name(name)) \(alt) \(f)]"
            case .deviceN(let names, let alternate, let fn):
                let alt = colorSpaceObject(alternate)
                let f = fn.map { function($0) } ?? identityTint(for: alternate)
                let ns = "[" + names.map(Builder.name).joined(separator: " ") + "]"
                return "[/DeviceN \(ns) \(alt) \(f)]"
            case .indexed(let base, _, _):
                return colorSpaceObject(base)
            case .pattern(let base):
                return base.map { colorSpaceObject($0) } ?? "/DeviceGray"
            case .unknown:
                return "/DeviceGray"
            }
        }

        /// tint 関数が無いときの保険: tint 1 で代替色空間の「全部 1」へ
        private func identityTint(for alternate: PDFColorSpaceInfo) -> String {
            let n = max(alternate.componentCount, 1)
            let c0 = Array(repeating: CGFloat(0), count: n)
            let c1 = Array(repeating: CGFloat(1), count: n)
            return "<< /FunctionType 2 /Domain [0 1] /C0 \(Builder.nums(c0)) /C1 \(Builder.nums(c1)) /N 1 >>"
        }

        /// PDF 関数。辞書型はインライン、ストリーム型 (Type 0 / 4) は間接オブジェクト。
        private mutating func function(_ fn: PDFFunction) -> String {
            var common = "/Domain \(Builder.nums(fn.domain))"
            if let r = fn.range { common += " /Range \(Builder.nums(r))" }
            switch fn.kind {
            case .exponential(let c0, let c1, let n):
                return "<< /FunctionType 2 \(common) /C0 \(Builder.nums(c0)) /C1 \(Builder.nums(c1)) /N \(Builder.num(n)) >>"
            case .stitching(let functions, let bounds, let encode):
                let fs = "[" + functions.map { function($0) }.joined(separator: " ") + "]"
                return "<< /FunctionType 3 \(common) /Functions \(fs) /Bounds \(Builder.nums(bounds)) /Encode \(Builder.nums(encode)) >>"
            case .sampled(let data, let bps, let size, let encode, let decode):
                var dict = "/FunctionType 0 \(common) /Size [\(size.map(String.init).joined(separator: " "))] /BitsPerSample \(bps)"
                if !encode.isEmpty { dict += " /Encode \(Builder.nums(encode))" }
                if !decode.isEmpty { dict += " /Decode \(Builder.nums(decode))" }
                let ref = addStream(dict: dict, data: data)
                return "\(ref) 0 R"
            case .postScript(let source):
                let ref = addStream(dict: "/FunctionType 4 \(common)", data: source)
                return "\(ref) 0 R"
            case .array(let functions):
                return "[" + functions.map { function($0) }.joined(separator: " ") + "]"
            }
        }

        func finish(root: Int, info: Int) -> Data {
            var out = Data("%PDF-1.5\n%\u{E2}\u{E3}\u{CF}\u{D3}\n".utf8)
            var offsets: [Int] = []
            for (i, obj) in objects.enumerated() {
                offsets.append(out.count)
                out.append(Data("\(i + 1) 0 obj\n".utf8))
                out.append(obj ?? Data("null".utf8))
                out.append(Data("\nendobj\n".utf8))
            }
            let xref = out.count
            out.append(Data("xref\n0 \(objects.count + 1)\n0000000000 65535 f \n".utf8))
            for off in offsets {
                out.append(Data(String(format: "%010d 00000 n \n", off).utf8))
            }
            out.append(Data("trailer\n<< /Size \(objects.count + 1) /Root \(root) 0 R /Info \(info) 0 R >>\nstartxref\n\(xref)\n%%EOF\n".utf8))
            return out
        }
    }
}
