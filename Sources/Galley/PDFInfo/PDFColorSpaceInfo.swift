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

import AppKit
import CoreGraphics

// ==========================================
// PDF の色空間・色値のモデル (Color Picker 用)
//
// CGPDF* のオブジェクトは文書が所有しているので、ここでは名前・数値・
// バイト列だけをコピーして保持し、走査後もキャッシュに残せるようにする。
// ==========================================

/// PDF 関数 (ISO 32000-1 §7.10)。Separation / DeviceN の tint 変換に使う。
/// Type 4 (PostScript calculator) は評価しない (`evaluate` が nil を返す)。
final class PDFFunction {
    enum Kind {
        case sampled(data: Data, bitsPerSample: Int, size: [Int], encode: [CGFloat], decode: [CGFloat])
        case exponential(c0: [CGFloat], c1: [CGFloat], n: CGFloat)
        case stitching(functions: [PDFFunction], bounds: [CGFloat], encode: [CGFloat])
        case postScript
        case array([PDFFunction])   // 1 入力 → 各関数が 1 出力 (Shading で使われる形)
    }

    let kind: Kind
    let domain: [CGFloat]
    let range: [CGFloat]?

    init(kind: Kind, domain: [CGFloat], range: [CGFloat]?) {
        self.kind = kind
        self.domain = domain
        self.range = range
    }

    var isEvaluable: Bool {
        switch kind {
        case .postScript: return false
        case .stitching(let fns, _, _), .array(let fns): return fns.allSatisfy { $0.isEvaluable }
        default: return true
        }
    }

    func evaluate(_ inputs: [CGFloat]) -> [CGFloat]? {
        var x = inputs
        // Domain でクランプ
        for i in 0..<x.count where 2 * i + 1 < domain.count {
            x[i] = min(max(x[i], domain[2 * i]), domain[2 * i + 1])
        }

        var out: [CGFloat]
        switch kind {
        case .postScript:
            return nil

        case .array(let fns):
            var result: [CGFloat] = []
            for f in fns {
                guard let r = f.evaluate(x), let first = r.first else { return nil }
                result.append(first)
            }
            return result

        case .exponential(let c0, let c1, let n):
            let t = x.first ?? 0
            let p: CGFloat = (n == 1) ? t : pow(t, n)
            let count = max(c0.count, c1.count)
            out = (0..<count).map { j in
                let a = j < c0.count ? c0[j] : 0
                let b = j < c1.count ? c1[j] : 1
                return a + p * (b - a)
            }

        case .stitching(let fns, let bounds, let encode):
            let t = x.first ?? 0
            let d0 = domain.first ?? 0
            let d1 = domain.count > 1 ? domain[1] : 1
            var k = 0
            while k < bounds.count && t >= bounds[k] { k += 1 }
            guard k < fns.count else { return nil }
            let low = (k == 0) ? d0 : bounds[k - 1]
            let high = (k == bounds.count) ? d1 : bounds[k]
            let e0 = 2 * k < encode.count ? encode[2 * k] : 0
            let e1 = 2 * k + 1 < encode.count ? encode[2 * k + 1] : 1
            let tt = (high - low) == 0 ? e0 : e0 + (t - low) * (e1 - e0) / (high - low)
            guard let r = fns[k].evaluate([tt]) else { return nil }
            out = r

        case .sampled(let data, let bps, let size, let encode, let decode):
            guard let nOut = range.map({ $0.count / 2 }), nOut > 0, !size.isEmpty else { return nil }
            let maxVal = CGFloat(pow(2.0, Double(bps)) - 1)
            // 各入力次元を最近傍サンプルへ (1 入力の場合は線形補間)
            var indices: [Int] = []
            var frac: CGFloat = 0
            for i in 0..<size.count {
                let d0 = 2 * i < domain.count ? domain[2 * i] : 0
                let d1 = 2 * i + 1 < domain.count ? domain[2 * i + 1] : 1
                let e0 = 2 * i < encode.count ? encode[2 * i] : 0
                let e1 = 2 * i + 1 < encode.count ? encode[2 * i + 1] : CGFloat(size[i] - 1)
                let xi = i < x.count ? x[i] : d0
                var e = (d1 - d0) == 0 ? e0 : e0 + (xi - d0) * (e1 - e0) / (d1 - d0)
                e = min(max(e, 0), CGFloat(size[i] - 1))
                if i == 0 {
                    indices.append(Int(floor(e)))
                    frac = e - floor(e)
                } else {
                    indices.append(Int(e.rounded()))
                }
            }
            func sample(at idx: [Int], output j: Int) -> CGFloat? {
                var linear = 0
                var stride = 1
                for i in 0..<size.count {
                    linear += idx[i] * stride
                    stride *= size[i]
                }
                let bitOffset = (linear * nOut + j) * bps
                let byteOffset = bitOffset / 8
                guard byteOffset < data.count else { return nil }
                var value: UInt64 = 0
                switch bps {
                case 8:
                    value = UInt64(data[byteOffset])
                case 16:
                    guard byteOffset + 1 < data.count else { return nil }
                    value = UInt64(data[byteOffset]) << 8 | UInt64(data[byteOffset + 1])
                case 32:
                    guard byteOffset + 3 < data.count else { return nil }
                    for b in 0..<4 { value = value << 8 | UInt64(data[byteOffset + b]) }
                default:
                    // 1/2/4/12/24 bit: ビット単位で読む
                    var acc: UInt64 = 0
                    for b in 0..<bps {
                        let bit = bitOffset + b
                        let byte = bit / 8
                        guard byte < data.count else { return nil }
                        let v = (data[byte] >> (7 - UInt8(bit % 8))) & 1
                        acc = acc << 1 | UInt64(v)
                    }
                    value = acc
                }
                return CGFloat(value) / maxVal
            }
            out = []
            for j in 0..<nOut {
                guard let s0 = sample(at: indices, output: j) else { return nil }
                var s = s0
                if frac > 0, indices[0] + 1 < size[0] {
                    var idx2 = indices
                    idx2[0] += 1
                    if let s1 = sample(at: idx2, output: j) {
                        s = s0 + (s1 - s0) * frac
                    }
                }
                let dmin = 2 * j < decode.count ? decode[2 * j] : (range?[2 * j] ?? 0)
                let dmax = 2 * j + 1 < decode.count ? decode[2 * j + 1] : (range?[2 * j + 1] ?? 1)
                out.append(dmin + s * (dmax - dmin))
            }
        }

        // Range でクランプ
        if let range = range {
            for j in 0..<out.count where 2 * j + 1 < range.count {
                out[j] = min(max(out[j], range[2 * j]), range[2 * j + 1])
            }
        }
        return out
    }

    // MARK: - Parsing

    static func parse(_ obj: CGPDFObjectRef) -> PDFFunction? {
        var dict: CGPDFDictionaryRef?
        var stream: CGPDFStreamRef?
        var array: CGPDFArrayRef?

        if CGPDFObjectGetValue(obj, .array, &array), let arr = array {
            var fns: [PDFFunction] = []
            for i in 0..<CGPDFArrayGetCount(arr) {
                var o: CGPDFObjectRef?
                guard CGPDFArrayGetObject(arr, i, &o), let el = o, let f = parse(el) else { return nil }
                fns.append(f)
            }
            return PDFFunction(kind: .array(fns), domain: fns.first?.domain ?? [0, 1], range: nil)
        }

        if CGPDFObjectGetValue(obj, .stream, &stream), let s = stream {
            dict = CGPDFStreamGetDictionary(s)
        } else {
            _ = CGPDFObjectGetValue(obj, .dictionary, &dict)
        }
        guard let d = dict else { return nil }

        var typeInt: CGPDFInteger = 0
        guard CGPDFDictionaryGetInteger(d, "FunctionType", &typeInt) else { return nil }
        let domain = CGPDFHelpers.numberArray(d, "Domain") ?? [0, 1]
        let range = CGPDFHelpers.numberArray(d, "Range")

        switch typeInt {
        case 2:
            let c0 = CGPDFHelpers.numberArray(d, "C0") ?? [0]
            let c1 = CGPDFHelpers.numberArray(d, "C1") ?? [1]
            var n: CGPDFReal = 1
            _ = CGPDFDictionaryGetNumber(d, "N", &n)
            return PDFFunction(kind: .exponential(c0: c0, c1: c1, n: n), domain: domain, range: range)

        case 3:
            var fnArray: CGPDFArrayRef?
            guard CGPDFDictionaryGetArray(d, "Functions", &fnArray), let fa = fnArray else { return nil }
            var fns: [PDFFunction] = []
            for i in 0..<CGPDFArrayGetCount(fa) {
                var o: CGPDFObjectRef?
                guard CGPDFArrayGetObject(fa, i, &o), let el = o, let f = parse(el) else { return nil }
                fns.append(f)
            }
            let bounds = CGPDFHelpers.numberArray(d, "Bounds") ?? []
            let encode = CGPDFHelpers.numberArray(d, "Encode") ?? []
            return PDFFunction(kind: .stitching(functions: fns, bounds: bounds, encode: encode), domain: domain, range: range)

        case 0:
            guard let s = stream, let data = CGPDFHelpers.streamData(s) else { return nil }
            var bps: CGPDFInteger = 8
            _ = CGPDFDictionaryGetInteger(d, "BitsPerSample", &bps)
            let size = (CGPDFHelpers.numberArray(d, "Size") ?? []).map { Int($0) }
            let encode = CGPDFHelpers.numberArray(d, "Encode") ?? []
            let decode = CGPDFHelpers.numberArray(d, "Decode") ?? []
            return PDFFunction(kind: .sampled(data: data, bitsPerSample: Int(bps), size: size, encode: encode, decode: decode),
                               domain: domain, range: range)

        case 4:
            return PDFFunction(kind: .postScript, domain: domain, range: range)

        default:
            return nil
        }
    }
}

/// PDF の色空間 (ISO 32000-1 §8.6)。
indirect enum PDFColorSpaceInfo {
    case deviceGray
    case deviceRGB
    case deviceCMYK
    case iccBased(n: Int, alternate: PDFColorSpaceInfo?, iccData: Data?)
    case calGray
    case calRGB
    case lab(range: [CGFloat])
    case indexed(base: PDFColorSpaceInfo, hival: Int, lookup: Data)
    case separation(name: String, alternate: PDFColorSpaceInfo, tint: PDFFunction?)
    case deviceN(names: [String], alternate: PDFColorSpaceInfo, tint: PDFFunction?)
    case pattern(base: PDFColorSpaceInfo?)
    case unknown(String)

    /// 成分数。Pattern は 0 (色つきパターン) または base の成分数。
    var componentCount: Int {
        switch self {
        case .deviceGray, .calGray: return 1
        case .deviceRGB, .calRGB, .lab: return 3
        case .deviceCMYK: return 4
        case .iccBased(let n, _, _): return n
        case .indexed: return 1
        case .separation: return 1
        case .deviceN(let names, _, _): return names.count
        case .pattern(let base): return base?.componentCount ?? 0
        case .unknown: return 0
        }
    }

    /// 表示名。例: `DeviceCMYK`, `ICCBased (N=4)`, `Separation "DIC 161s*"`
    var displayName: String {
        switch self {
        case .deviceGray: return "DeviceGray"
        case .deviceRGB: return "DeviceRGB"
        case .deviceCMYK: return "DeviceCMYK"
        case .iccBased(let n, _, _): return "ICCBased (N=\(n))"
        case .calGray: return "CalGray"
        case .calRGB: return "CalRGB"
        case .lab: return "Lab"
        case .indexed(let base, _, _): return "Indexed (\(base.displayName))"
        case .separation(let name, _, _): return "Separation \"\(name)\""
        case .deviceN(let names, _, _): return "DeviceN [\(names.joined(separator: ", "))]"
        case .pattern(let base):
            if let b = base { return "Pattern (\(b.displayName))" }
            return "Pattern"
        case .unknown(let s): return s
        }
    }

    /// 色モデルの種類 (成分ラベル・書式の決定に使う)
    enum Model { case gray, rgb, cmyk, lab, tint, named, index, other }

    var model: Model {
        switch self {
        case .deviceGray, .calGray: return .gray
        case .deviceRGB, .calRGB: return .rgb
        case .deviceCMYK: return .cmyk
        case .lab: return .lab
        case .iccBased(let n, _, _):
            switch n {
            case 1: return .gray
            case 3: return .rgb
            case 4: return .cmyk
            default: return .other
            }
        case .separation: return .tint
        case .deviceN: return .named
        case .indexed: return .index
        case .pattern(let base): return base?.model ?? .other
        case .unknown: return .other
        }
    }

    /// 成分ラベル (成分数と同じ長さ)
    var componentLabels: [String] {
        switch model {
        case .gray: return ["Gray"]
        case .rgb: return ["R", "G", "B"]
        case .cmyk: return ["C", "M", "Y", "K"]
        case .lab: return ["L", "a", "b"]
        case .tint: return ["Tint"]
        case .named:
            if case .deviceN(let names, _, _) = self { return names }
            return []
        case .index: return ["Index"]
        case .other: return (0..<componentCount).map { "c\($0)" }
        }
    }

    /// 色空間選択直後の初期色 (§8.6.3)
    var initialComponents: [CGFloat] {
        switch self {
        case .deviceCMYK: return [0, 0, 0, 1]
        case .iccBased(let n, _, _): return n == 4 ? [0, 0, 0, 1] : Array(repeating: 0, count: n)
        case .separation: return [1]
        case .deviceN(let names, _, _): return Array(repeating: 1, count: names.count)
        case .lab: return [0, 0, 0]
        default: return Array(repeating: 0, count: componentCount)
        }
    }

    /// CMYK 系 (ラスタサンプリングを CMYK コンテキストで行うべきか)
    var isCMYKFamily: Bool {
        switch self {
        case .deviceCMYK: return true
        case .iccBased(let n, _, _): return n == 4
        case .separation(_, let alt, _), .deviceN(_, let alt, _): return alt.isCMYKFamily
        case .indexed(let base, _, _): return base.isCMYKFamily
        case .pattern(let base): return base?.isCMYKFamily ?? false
        default: return false
        }
    }

    // MARK: - Parsing

    /// 色空間オブジェクト (名前または配列) を解決する。
    /// 名前がデバイス色空間でなければ `contentStream` の /ColorSpace リソースを引く。
    static func parse(_ obj: CGPDFObjectRef, in contentStream: CGPDFContentStreamRef?, depth: Int = 0) -> PDFColorSpaceInfo? {
        guard depth < 8 else { return nil }

        var namePtr: UnsafePointer<CChar>?
        if CGPDFObjectGetValue(obj, .name, &namePtr), let p = namePtr {
            let name = String(cString: p)
            if let literal = literalSpace(named: name) { return literal }
            guard let cs = contentStream,
                  let res = CGPDFContentStreamGetResource(cs, "ColorSpace", name) else {
                return .unknown(name)
            }
            return parse(res, in: contentStream, depth: depth + 1) ?? .unknown(name)
        }

        var arrayRef: CGPDFArrayRef?
        guard CGPDFObjectGetValue(obj, .array, &arrayRef), let arr = arrayRef else { return nil }
        let count = CGPDFArrayGetCount(arr)
        guard count >= 1 else { return nil }

        var familyPtr: UnsafePointer<CChar>?
        guard CGPDFArrayGetName(arr, 0, &familyPtr), let fp = familyPtr else { return nil }
        let family = String(cString: fp)

        func element(_ i: Int) -> CGPDFObjectRef? {
            var o: CGPDFObjectRef?
            guard i < count, CGPDFArrayGetObject(arr, i, &o) else { return nil }
            return o
        }
        func subspace(_ i: Int) -> PDFColorSpaceInfo? {
            guard let o = element(i) else { return nil }
            return parse(o, in: contentStream, depth: depth + 1)
        }

        switch family {
        case "DeviceGray", "G": return .deviceGray
        case "DeviceRGB", "RGB": return .deviceRGB
        case "DeviceCMYK", "CMYK": return .deviceCMYK
        case "CalGray": return .calGray
        case "CalRGB": return .calRGB
        case "Lab":
            var range: [CGFloat] = [-100, 100, -100, 100]
            if let o = element(1) {
                var d: CGPDFDictionaryRef?
                if CGPDFObjectGetValue(o, .dictionary, &d), let dd = d,
                   let r = CGPDFHelpers.numberArray(dd, "Range"), r.count == 4 {
                    range = r
                }
            }
            return .lab(range: range)

        case "ICCBased":
            guard let o = element(1) else { return .iccBased(n: 0, alternate: nil, iccData: nil) }
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(o, .stream, &stream), let s = stream,
                  let sd = CGPDFStreamGetDictionary(s) else {
                return .iccBased(n: 0, alternate: nil, iccData: nil)
            }
            var n: CGPDFInteger = 0
            _ = CGPDFDictionaryGetInteger(sd, "N", &n)
            var alternate: PDFColorSpaceInfo? = nil
            var altObj: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(sd, "Alternate", &altObj), let ao = altObj {
                alternate = parse(ao, in: contentStream, depth: depth + 1)
            }
            let data = CGPDFHelpers.streamData(s)
            return .iccBased(n: Int(n), alternate: alternate, iccData: data)

        case "Indexed", "I":
            guard let base = subspace(1) else { return nil }
            var hival: CGPDFInteger = 0
            _ = CGPDFArrayGetInteger(arr, 2, &hival)
            var lookup = Data()
            if let o = element(3) {
                var str: CGPDFStringRef?
                var stream: CGPDFStreamRef?
                if CGPDFObjectGetValue(o, .string, &str), let s = str,
                   let bytes = CGPDFStringGetBytePtr(s) {
                    lookup = Data(bytes: bytes, count: CGPDFStringGetLength(s))
                } else if CGPDFObjectGetValue(o, .stream, &stream), let s = stream,
                          let d = CGPDFHelpers.streamData(s) {
                    lookup = d
                }
            }
            return .indexed(base: base, hival: Int(hival), lookup: lookup)

        case "Separation":
            var np: UnsafePointer<CChar>?
            let name = (CGPDFArrayGetName(arr, 1, &np) && np != nil) ? CGPDFHelpers.decodeName(String(cString: np!)) : "?"
            let alt = subspace(2) ?? .deviceGray
            let fn = element(3).flatMap { PDFFunction.parse($0) }
            return .separation(name: name, alternate: alt, tint: fn)

        case "DeviceN":
            var names: [String] = []
            var namesArr: CGPDFArrayRef?
            if CGPDFArrayGetArray(arr, 1, &namesArr), let na = namesArr {
                for i in 0..<CGPDFArrayGetCount(na) {
                    var np: UnsafePointer<CChar>?
                    if CGPDFArrayGetName(na, i, &np), let p = np {
                        names.append(CGPDFHelpers.decodeName(String(cString: p)))
                    }
                }
            }
            let alt = subspace(2) ?? .deviceGray
            let fn = element(3).flatMap { PDFFunction.parse($0) }
            return .deviceN(names: names, alternate: alt, tint: fn)

        case "Pattern":
            return .pattern(base: subspace(1))

        default:
            return .unknown(family)
        }
    }

    static func literalSpace(named name: String) -> PDFColorSpaceInfo? {
        switch name {
        case "DeviceGray", "G": return .deviceGray
        case "DeviceRGB", "RGB": return .deviceRGB
        case "DeviceCMYK", "CMYK": return .deviceCMYK
        case "Pattern": return .pattern(base: nil)
        default: return nil
        }
    }
}

/// 塗り (または線) の色: 色空間 + 生の成分値 (+ パターン名)。
struct PDFPaintColor {
    var space: PDFColorSpaceInfo
    var components: [CGFloat]
    var patternName: String? = nil
    /// Pattern の付帯情報 (走査時に解決)
    var pattern: PDFPatternInfo? = nil

    static let initial = PDFPaintColor(space: .deviceGray, components: [0])

    /// 成分値の整形。CMYK/Gray/Tint は % (0–100)、RGB/Lab は小数。
    /// 例: `C 0  M 100  Y 100  K 0`
    var formattedComponents: String {
        let labels = space.componentLabels
        var parts: [String] = []
        for (i, v) in components.enumerated() {
            let label = i < labels.count ? labels[i] : "c\(i)"
            parts.append("\(label) \(PDFPaintColor.formatValue(v, model: space.model))")
        }
        if parts.isEmpty, let p = patternName {
            return "/\(p)"
        }
        return parts.joined(separator: "  ")
    }

    /// 1 行 1 成分の整形 (パネルの縦並び表示用)。`("C", "0")` のような組。
    var componentPairs: [(String, String)] {
        let labels = space.componentLabels
        return components.enumerated().map { (i, v) in
            (i < labels.count ? labels[i] : "c\(i)", PDFPaintColor.formatValue(v, model: space.model))
        }
    }

    static func formatValue(_ v: CGFloat, model: PDFColorSpaceInfo.Model) -> String {
        switch model {
        case .cmyk, .gray, .tint, .named:
            let pct = v * 100
            if abs(pct - pct.rounded()) < 0.05 {
                return String(format: "%.0f%%", pct)
            }
            return String(format: "%.1f%%", pct)
        case .index:
            return String(format: "%.0f", v)
        case .lab:
            return String(format: "%.1f", v)
        case .rgb, .other:
            return String(format: "%.3f", v)
        }
    }

    /// RGB のとき 0–255 表記 (`R 0  G 102  B 255`)
    var formatted255: String? {
        guard space.model == .rgb, components.count == 3 else { return nil }
        let labels = space.componentLabels
        return zip(labels, components).map { "\($0) \(Int(($1 * 255).rounded()))" }.joined(separator: "  ")
    }

    /// Separation / DeviceN の代替色空間での値 (tint 変換を評価)
    var alternateColor: PDFPaintColor? {
        switch space {
        case .separation(_, let alt, let fn), .deviceN(_, let alt, let fn):
            guard let f = fn, let out = f.evaluate(components) else { return nil }
            return PDFPaintColor(space: alt, components: out)
        default:
            return nil
        }
    }

    /// 近似 sRGB (スウォッチ・hex 表示用)。カラーマネジメント経由の近似値。
    func approximateSRGB(depth: Int = 0) -> NSColor? {
        guard depth < 6 else { return nil }
        let comps = components

        func fromCG(_ cs: CGColorSpace?, _ c: [CGFloat]) -> NSColor? {
            guard let cs = cs, cs.numberOfComponents == c.count else { return nil }
            let cg = CGColor(colorSpace: cs, components: c + [1.0])
            return cg.flatMap { NSColor(cgColor: $0) }?.usingColorSpace(.sRGB)
        }

        switch space {
        case .deviceGray, .calGray:
            return fromCG(CGColorSpaceCreateDeviceGray(), comps)
        case .deviceRGB, .calRGB:
            return fromCG(CGColorSpaceCreateDeviceRGB(), comps)
        case .deviceCMYK:
            return fromCG(CGColorSpaceCreateDeviceCMYK(), comps)
        case .lab(let range):
            let white: [CGFloat] = [0.9505, 1.0, 1.089]
            let cs = CGColorSpace(labWhitePoint: white, blackPoint: nil, range: range)
            return fromCG(cs, comps)
        case .iccBased(let n, let alternate, let iccData):
            if let data = iccData, let cs = CGColorSpace(iccData: data as CFData), cs.numberOfComponents == comps.count,
               let c = fromCG(cs, comps) {
                return c
            }
            if let alt = alternate {
                return PDFPaintColor(space: alt, components: comps).approximateSRGB(depth: depth + 1)
            }
            switch n {
            case 1: return fromCG(CGColorSpaceCreateDeviceGray(), comps)
            case 3: return fromCG(CGColorSpaceCreateDeviceRGB(), comps)
            case 4: return fromCG(CGColorSpaceCreateDeviceCMYK(), comps)
            default: return nil
            }
        case .indexed(let base, let hival, let lookup):
            guard let idxF = comps.first else { return nil }
            let idx = min(max(Int(idxF.rounded()), 0), hival)
            let n = base.componentCount
            guard n > 0, (idx + 1) * n <= lookup.count else { return nil }
            var baseComps: [CGFloat] = (0..<n).map { CGFloat(lookup[idx * n + $0]) / 255.0 }
            if case .lab(let range) = base, baseComps.count == 3 {
                baseComps[0] *= 100
                baseComps[1] = range[0] + baseComps[1] * (range[1] - range[0])
                baseComps[2] = range[2] + baseComps[2] * (range[3] - range[2])
            }
            return PDFPaintColor(space: base, components: baseComps).approximateSRGB(depth: depth + 1)
        case .separation, .deviceN:
            return alternateColor?.approximateSRGB(depth: depth + 1)
        case .pattern(let base):
            if let b = base, !comps.isEmpty {
                return PDFPaintColor(space: b, components: comps).approximateSRGB(depth: depth + 1)
            }
            return nil
        case .unknown:
            return nil
        }
    }

    static func hexString(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return "?" }
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

/// `scn /P1` で参照されたパターンの付帯情報
struct PDFPatternInfo {
    enum Kind { case tiling(colored: Bool), shading(colorSpace: PDFColorSpaceInfo?) }
    let name: String
    let kind: Kind

    var description: String {
        switch kind {
        case .tiling(let colored): return "Pattern /\(name) (tiling, \(colored ? "colored" : "uncolored"))"
        case .shading(let cs): return "Pattern /\(name) (shading\(cs.map { ", \($0.displayName)" } ?? ""))"
        }
    }
}

/// CGPDF 辞書まわりの小道具
enum CGPDFHelpers {
    static func numberArray(_ dict: CGPDFDictionaryRef, _ key: String) -> [CGFloat]? {
        var arr: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, key, &arr), let a = arr else { return nil }
        return numberArray(a)
    }

    static func numberArray(_ a: CGPDFArrayRef) -> [CGFloat] {
        var out: [CGFloat] = []
        for i in 0..<CGPDFArrayGetCount(a) {
            var v: CGPDFReal = 0
            if CGPDFArrayGetNumber(a, i, &v) { out.append(v) }
        }
        return out
    }

    static func name(_ dict: CGPDFDictionaryRef, _ key: String) -> String? {
        var p: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dict, key, &p), let cp = p else { return nil }
        return String(cString: cp)
    }

    static func number(_ dict: CGPDFDictionaryRef, _ key: String) -> CGFloat? {
        var v: CGPDFReal = 0
        guard CGPDFDictionaryGetNumber(dict, key, &v) else { return nil }
        return v
    }

    static func integer(_ dict: CGPDFDictionaryRef, _ key: String) -> Int? {
        var v: CGPDFInteger = 0
        guard CGPDFDictionaryGetInteger(dict, key, &v) else { return nil }
        return Int(v)
    }

    static func bool(_ dict: CGPDFDictionaryRef, _ key: String) -> Bool? {
        var v: CGPDFBoolean = 0
        guard CGPDFDictionaryGetBoolean(dict, key, &v) else { return nil }
        return v != 0
    }

    static func streamData(_ s: CGPDFStreamRef) -> Data? {
        var format = CGPDFDataFormat.raw
        guard let cf = CGPDFStreamCopyData(s, &format) else { return nil }
        return cf as Data
    }

    /// PDF 名前オブジェクトの `#xx` エスケープを戻す (`DIC#20161s*` → `DIC 161s*`)
    static func decodeName(_ s: String) -> String {
        guard s.contains("#") else { return s }
        var bytes: [UInt8] = []
        let utf8 = Array(s.utf8)
        var i = 0
        while i < utf8.count {
            if utf8[i] == UInt8(ascii: "#"), i + 2 < utf8.count,
               let hi = hexValue(utf8[i + 1]), let lo = hexValue(utf8[i + 2]) {
                bytes.append(hi << 4 | lo)
                i += 3
            } else {
                bytes.append(utf8[i])
                i += 1
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func hexValue(_ c: UInt8) -> UInt8? {
        switch c {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return c - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return c - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return c - UInt8(ascii: "A") + 10
        default: return nil
        }
    }
}
