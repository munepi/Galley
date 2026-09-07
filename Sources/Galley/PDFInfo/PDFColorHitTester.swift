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
import PDFKit

// ==========================================
// Color Picker のヒットテスト: ページ座標の 1 点に対して、走査結果から
// 「そこに描かれているもの」と「その色 (生値)」を返す。
// 画像・シェーディング・色付きパターンは生値が無いので、ラスタサンプリング
// (PDFColorSampler) の近似値で補う。
// ==========================================

/// ラスタサンプリングの結果 (カラーマネジメント経由の近似値)
struct PDFColorSample {
    let color: PDFPaintColor   // .deviceCMYK または .deviceRGB
}

struct PDFColorHit {
    enum Kind {
        case text(character: String?)
        case fill
        case stroke(lineWidth: CGFloat)
        case image(colorSpace: PDFColorSpaceInfo?, bitsPerComponent: Int?, isMask: Bool, isInline: Bool)
        case shading(colorSpace: PDFColorSpaceInfo?, shadingType: Int?)
        case noInk
        case noPage
    }

    var kind: Kind
    /// 生の色値 (テキスト・塗り・線・画像マスク・非色付きパターン)
    var color: PDFPaintColor?
    /// Tr 1/2/5/6 のテキストの線色
    var strokeColor: PDFPaintColor?
    var alpha: CGFloat = 1
    var blendMode: String? = nil
    var notes: [String] = []
    /// 生値が無く、ラスタサンプリングで補うべきか
    var needsSampling = false
    /// サンプリングを CMYK コンテキストで行うか
    var sampleInCMYK = false
    /// ラスタサンプリングの結果 (後から埋める)
    var sample: PDFColorSample?

    static let noPage = PDFColorHit(kind: .noPage, color: nil)
    static let noInk = PDFColorHit(kind: .noInk, color: nil)

    /// 対象の短い説明。例: `Text "あ"`, `Fill`, `Stroke 0.40 pt`, `Image DeviceRGB 8 bpc`
    var kindDescription: String {
        switch kind {
        case .text(let ch):
            if let c = ch, !c.isEmpty {
                let shown = c.unicodeScalars.allSatisfy { $0.properties.isWhitespace } ? "␣" : c
                return "Text \"\(shown)\""
            }
            return "Text"
        case .fill:
            return "Fill"
        case .stroke(let lw):
            if lw <= 0 { return "Stroke (hairline)" }
            return String(format: "Stroke %.2f pt", lw)
        case .image(let cs, let bpc, let isMask, let isInline):
            var s = isInline ? "Inline image" : "Image"
            if isMask {
                s += " mask"
            } else if let c = cs {
                s += " " + c.displayName
            }
            if let b = bpc { s += " \(b) bpc" }
            return s
        case .shading(let cs, let type):
            var s = "Shading"
            if let t = type { s += " (type \(t))" }
            if let c = cs { s += " " + c.displayName }
            return s
        case .noInk:
            return "No ink"
        case .noPage:
            return "No page"
        }
    }

    /// 表示に使う主となる色空間名
    var spaceDescription: String {
        if let c = color {
            if let p = c.pattern { return p.description }
            return c.space.displayName
        }
        switch kind {
        case .image(let cs, _, _, _), .shading(let cs, _):
            return cs?.displayName ?? "—"
        default:
            return "—"
        }
    }

    /// スウォッチ用の近似 sRGB
    var swatchColor: NSColor? {
        if let s = sample { return s.color.approximateSRGB() }
        if let c = color { return c.approximateSRGB() }
        return nil
    }
}

enum PDFColorHitTester {

    /// ページ座標 `point` の色を求める。`tolerance` はページ座標での許容量
    /// (画面 2px 程度を scaleFactor で割ったもの)。
    static func hit(page: PDFPage, point: CGPoint, tolerance: CGFloat) -> PDFColorHit {
        guard let scan = PDFColorScanCache.shared.result(for: page) else {
            return PDFColorHit(kind: .noInk, color: nil, notes: ["content stream unavailable"])
        }

        var notes: [String] = []

        // 1. テキスト (PDFKit の文字矩形 → 直前に始まった TextRun)
        let charIndex = page.characterIndex(at: point)
        if charIndex >= 0 {
            let bounds = page.characterBounds(at: charIndex)
            if let run = bestTextRun(in: scan, glyphBounds: bounds) {
                let ch = character(in: page, at: charIndex)
                if run.renderMode == 3 || run.renderMode == 7 {
                    notes.append("invisible text (Tr \(run.renderMode)) here")
                } else {
                    var h = textHit(run: run, character: ch)
                    h.notes = notes
                    return h
                }
            }
        }

        // 2. パス・画像・シェーディング (描画順の逆 = 上にあるものから)
        for ink in scan.inks.reversed() {
            switch ink {
            case .text:
                continue

            case .path(let po):
                guard clipContains(po.clip, point, tolerance) else { continue }
                if po.isStroke {
                    let w = max(po.lineWidth, tolerance * 2)
                    let outline = po.path.copy(strokingWithWidth: w, lineCap: .butt, lineJoin: .miter, miterLimit: 10)
                    guard outline.contains(point, using: .winding) else { continue }
                    var h = PDFColorHit(kind: .stroke(lineWidth: po.lineWidth), color: po.color)
                    h.alpha = po.alpha
                    h.blendMode = po.blendMode
                    h.notes = notes
                    applyPatternSampling(&h, color: po.color)
                    return h
                } else {
                    let bbox = po.path.boundingBoxOfPath
                    let thin = min(bbox.width, bbox.height) < tolerance * 2
                    let inside = po.path.contains(point, using: po.evenOdd ? .evenOdd : .winding)
                        || (thin && bbox.insetBy(dx: -tolerance, dy: -tolerance).contains(point))
                    guard inside else { continue }
                    var h = PDFColorHit(kind: .fill, color: po.color)
                    h.alpha = po.alpha
                    h.blendMode = po.blendMode
                    h.notes = notes
                    applyPatternSampling(&h, color: po.color)
                    return h
                }

            case .image(let io):
                guard clipContains(io.clip, point, tolerance),
                      io.bounds.contains(point, using: .winding) else { continue }
                var h = PDFColorHit(kind: .image(colorSpace: io.colorSpace, bitsPerComponent: io.bitsPerComponent,
                                                 isMask: io.isMask, isInline: io.isInline),
                                    color: io.isMask ? io.fill : nil)
                h.alpha = io.alpha
                h.notes = notes
                if io.isMask {
                    h.notes.append("stencil mask: painted where the mask is set")
                } else {
                    h.needsSampling = true
                    h.sampleInCMYK = io.colorSpace?.isCMYKFamily ?? false
                }
                return h

            case .shading(let so):
                guard clipContains(so.clip, point, tolerance) else { continue }
                var h = PDFColorHit(kind: .shading(colorSpace: so.colorSpace, shadingType: so.shadingType), color: nil)
                h.alpha = so.alpha
                h.notes = notes
                h.needsSampling = true
                h.sampleInCMYK = so.colorSpace?.isCMYKFamily ?? false
                return h
            }
        }

        var h = PDFColorHit.noInk
        h.notes = notes
        if page.annotation(at: point) != nil {
            h.notes.append("annotation here (not scanned)")
        }
        return h
    }

    /// 文字インスペクタ用: 文字矩形からテキストの塗り色だけを求める
    static func hitText(page: PDFPage, characterIndex: Int) -> PDFColorHit? {
        guard characterIndex >= 0,
              let scan = PDFColorScanCache.shared.result(for: page) else { return nil }
        let bounds = page.characterBounds(at: characterIndex)
        guard let run = bestTextRun(in: scan, glyphBounds: bounds) else { return nil }
        return textHit(run: run, character: character(in: page, at: characterIndex))
    }

    // MARK: - Helpers

    private static func textHit(run: CGPDFPageColorScanner.TextRun, character: String?) -> PDFColorHit {
        var h = PDFColorHit(kind: .text(character: character), color: run.fill)
        h.alpha = run.alpha
        h.blendMode = run.blendMode
        switch run.renderMode {
        case 1, 5:
            h.color = run.stroke
            h.notes.append("outlined text (Tr \(run.renderMode)): stroke color")
        case 2, 6:
            h.strokeColor = run.stroke
        default:
            break
        }
        if run.font?.subtype == "Type3" {
            h.notes.append("Type3 font")
        }
        applyPatternSampling(&h, color: h.color)
        return h
    }

    /// 色付きパターン (tiling colored / shading pattern) は生値が無いのでサンプリングへ
    private static func applyPatternSampling(_ h: inout PDFColorHit, color: PDFPaintColor?) {
        guard let c = color, let p = c.pattern else { return }
        switch p.kind {
        case .tiling(let colored):
            if colored {
                h.needsSampling = true
                h.sampleInCMYK = false
            }
        case .shading(let cs):
            h.needsSampling = true
            h.sampleInCMYK = cs?.isCMYKFamily ?? false
        }
    }

    private static func clipContains(_ clip: CGRect?, _ point: CGPoint, _ tol: CGFloat) -> Bool {
        guard let c = clip else { return true }
        if c.isNull { return false }
        return c.insetBy(dx: -tol, dy: -tol).contains(point)
    }

    private static func character(in page: PDFPage, at index: Int) -> String? {
        guard let s = page.string as NSString?, index >= 0, index < s.length else { return nil }
        let range = s.rangeOfComposedCharacterSequence(at: index)
        return s.substring(with: range)
    }

    /// 文字矩形の中心を各 TextRun のテキスト空間へ写し、同じベースライン上で
    /// 直前に始まった run を選ぶ。
    static func bestTextRun(in scan: CGPDFPageColorScanner.ScanResult, glyphBounds: CGRect) -> CGPDFPageColorScanner.TextRun? {
        guard !glyphBounds.isNull, !glyphBounds.isEmpty else { return nil }
        let center = CGPoint(x: glyphBounds.midX, y: glyphBounds.midY)
        let glyphExtent = max(glyphBounds.height, glyphBounds.width)

        var best: CGPDFPageColorScanner.TextRun? = nil
        var bestScore = CGFloat.greatestFiniteMagnitude

        for ink in scan.inks {
            guard case .text(let run) = ink else { continue }
            if run.effectiveSize > 0 {
                let ratio = glyphExtent / run.effectiveSize
                guard ratio >= 0.25, ratio <= 3.0 else { continue }
            }
            let p = center.applying(run.inverse)
            let score: CGFloat
            if run.font?.isVertical == true {
                guard abs(p.x) <= 0.75, p.y <= 0.1 else { continue }
                // 縦書きは -y 方向に進む。長さが分かれば run の範囲内に限定
                if let len = run.lengthInGlyphUnits, len < 0, p.y < len - 0.1 { continue }
                score = -p.y
            } else {
                guard p.y >= -0.45, p.y <= 1.1, p.x >= -0.1 else { continue }
                if let len = run.lengthInGlyphUnits, len > 0, p.x > len + 0.1 { continue }
                score = p.x
            }
            // 同点は後に描かれた run を優先 (<=)
            if score <= bestScore {
                bestScore = score
                best = run
            }
        }
        return best
    }
}

// ==========================================
// ラスタサンプリング: 1 点の周辺を小さくラスタライズして色を読む。
// DeviceCMYK のインクは CMYK コンテキストで往復一致するが、それ以外は
// Generic CMYK / sRGB プロファイル経由の近似値になる。
// ==========================================
enum PDFColorSampler {

    /// `point` (ページ座標 = 生の user space) の色をサンプリングする。
    static func sample(page: PDFPage, at point: CGPoint, cmyk: Bool) -> PDFColorSample? {
        guard let pageRef = page.pageRef else { return nil }

        let size = 3
        let scale: CGFloat = 4
        let space: CGColorSpace
        let bitmapInfo: UInt32
        if cmyk {
            space = CGColorSpaceCreateDeviceCMYK()
            bitmapInfo = CGImageAlphaInfo.none.rawValue
        } else {
            guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
            space = srgb
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        }
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: space, bitmapInfo: bitmapInfo) else {
            return nil
        }

        // 白で前塗り (CMYK は 0,0,0,0)
        let white: [CGFloat] = cmyk ? [0, 0, 0, 0, 1] : [1, 1, 1, 1]
        if let w = CGColor(colorSpace: space, components: white) {
            ctx.setFillColor(w)
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }

        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none
        ctx.setAllowsFontSmoothing(false)
        ctx.setShouldSmoothFonts(false)

        // 中心画素 (1.5, 1.5) がページ座標 point に来るように
        let half = CGFloat(size) / 2
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: half / scale - point.x, y: half / scale - point.y)
        ctx.drawPDFPage(pageRef)

        guard let data = ctx.data else { return nil }
        let row = ctx.bytesPerRow
        let px = data.advanced(by: (size / 2) * row + (size / 2) * 4).assumingMemoryBound(to: UInt8.self)
        if cmyk {
            let comps = (0..<4).map { CGFloat(px[$0]) / 255.0 }
            return PDFColorSample(color: PDFPaintColor(space: .deviceCMYK, components: comps))
        } else {
            let comps = (0..<3).map { CGFloat(px[$0]) / 255.0 }
            return PDFColorSample(color: PDFPaintColor(space: .deviceRGB, components: comps))
        }
    }

    /// 拡大鏡用の画像。`center` (ページ座標) を中心に `extent` pt 四方を
    /// `pixels` px 四方へ描く。Page Color は掛からない (文書本来の色)。
    static func magnifierImage(page: PDFPage, center: CGPoint, extent: CGFloat, pixels: Int) -> NSImage? {
        guard pixels > 0, extent > 0 else { return nil }
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        defer { image.unlockFocus() }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()

        // page.draw(with:to:) は /Rotate と box の原点を内部で適用するので、
        // 中心点も同じ変換で表示空間へ写してから平行移動する
        let t = page.transform(for: .cropBox)
        let dc = center.applying(t)
        let scale = CGFloat(pixels) / extent
        ctx.saveGState()
        ctx.interpolationQuality = .high
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: extent / 2 - dc.x, y: extent / 2 - dc.y)
        page.draw(with: .cropBox, to: ctx)
        ctx.restoreGState()

        // 中央のレティクル (1 pt 四方の枠を画面上 8px 程度で)
        let r: CGFloat = max(4, CGFloat(pixels) / 22)
        let cx = CGFloat(pixels) / 2, cy = CGFloat(pixels) / 2
        let box = NSRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
        NSColor.white.setStroke()
        let outer = NSBezierPath(rect: box.insetBy(dx: -1, dy: -1))
        outer.lineWidth = 3
        outer.stroke()
        NSColor.black.setStroke()
        let inner = NSBezierPath(rect: box)
        inner.lineWidth = 1
        inner.stroke()
        return image
    }
}

// ==========================================
// ページごとの走査結果キャッシュ (PDFPage を弱参照キーに)
// ==========================================
final class PDFColorScanCache {
    static let shared = PDFColorScanCache()

    private let table = NSMapTable<PDFPage, CGPDFPageColorScanner.ScanResult>.weakToStrongObjects()

    func result(for page: PDFPage) -> CGPDFPageColorScanner.ScanResult? {
        if let r = table.object(forKey: page) { return r }
        guard let r = CGPDFPageColorScanner.scan(page) else { return nil }
        table.setObject(r, forKey: page)
        return r
    }

    func flush() {
        table.removeAllObjects()
    }
}
