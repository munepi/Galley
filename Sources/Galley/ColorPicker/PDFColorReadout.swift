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

// ==========================================
// 拾った色を「表示モード」で言い換える (sRGB / P3 / Adobe RGB / Lab /
// シミュレーション CMYK) と、分版 (プロセス 4 版 + 特色版) と TAC の計算。
//
// CMYK 系の色はシミュレーションプロファイルの色空間で CGColor にしてから
// 変換するので、Generic CMYK ではなく出力インテントに沿った値になる。
// ここは nonisolated。CGColorSpace は引数で受け取るだけで保持しない。
// ==========================================
enum PDFColorReadout {

    static let processNames = ["Cyan", "Magenta", "Yellow", "Black"]
    static let processShortNames = ["C", "M", "Y", "K"]

    // MARK: - Display modes

    struct DisplayedColor {
        var pairs: [(String, String)]
        /// RGB 系のときの 0–255 表記
        var line255: String?
        /// 表示経路の説明。例: `Display P3 ← DeviceCMYK via Japan Color 2001 Coated`
        var title: String
        /// 変換を通した値か (native でない)
        var isApproximate: Bool
    }

    /// 表示モードに応じた成分値。入力はサンプル値があればそれ、無ければ生値。
    static func display(_ hit: PDFColorHit, mode: ColorDisplayMode,
                        simulation: CGColorSpace, simulationName: String) -> DisplayedColor? {
        guard let src = hit.sample?.color ?? hit.color else { return nil }
        let srcName = hit.sample != nil ? "\(src.space.displayName) (sampled)" : src.space.displayName

        if mode == .native {
            var pairs = src.componentPairs
            if pairs.isEmpty, let pn = src.patternName { pairs = [("Pattern", "/\(pn)")] }
            return DisplayedColor(pairs: pairs, line255: src.formatted255, title: srcName, isApproximate: false)
        }

        // Simulation CMYK: グレーと CMYK は分版と同じ直接対応 (Gray → K のみ、CMYK はそのまま)
        if mode == .simulationCMYK, let direct = directProcess(src) {
            let pairs = zip(processShortNames, direct).map { ($0, PDFPaintColor.formatValue($1, model: .cmyk)) }
            return DisplayedColor(pairs: pairs, line255: nil,
                                  title: "\(mode.title) ← \(srcName) via \(simulationName)", isApproximate: true)
        }

        let destination: CGColorSpace
        if mode == .simulationCMYK {
            destination = simulation
        } else {
            guard let d = mode.destinationSpace else { return nil }
            destination = d
        }
        guard let cg = src.cgColor(cmyk: simulation),
              let converted = convert(cg, to: destination),
              let comps = converted.components else { return nil }
        let values = Array(comps.prefix(destination.numberOfComponents))

        var pairs: [(String, String)] = []
        var line255: String? = nil
        switch mode {
        case .lab:
            guard values.count == 3 else { return nil }
            pairs = [("L", String(format: "%.1f", values[0])),
                     ("a", String(format: "%+.1f", values[1])),
                     ("b", String(format: "%+.1f", values[2]))]
        case .simulationCMYK:
            guard values.count == 4 else { return nil }
            pairs = zip(processShortNames, values).map { ($0, PDFPaintColor.formatValue($1, model: .cmyk)) }
        default:
            guard values.count == 3 else { return nil }
            let labels = ["R", "G", "B"]
            pairs = zip(labels, values).map { ($0, String(format: "%.3f", $1)) }
            line255 = zip(labels, values).map { "\($0) \(Int(($1 * 255).rounded()))" }.joined(separator: "  ")
        }

        let viaCMYK = src.space.isCMYKFamily || src.space.model == .tint || src.space.model == .named
        var title = "\(mode.title) ← \(srcName)"
        if viaCMYK || mode == .simulationCMYK {
            title += " via \(simulationName)"
        }
        return DisplayedColor(pairs: pairs, line255: line255, title: title, isApproximate: true)
    }

    /// グレー・CMYK の色をプロセス 4 版へ直接写す (変換を通さない)。それ以外は nil。
    static func directProcess(_ color: PDFPaintColor, depth: Int = 0) -> [CGFloat]? {
        guard depth < 6 else { return nil }
        let comps = color.components
        switch color.space {
        case .deviceCMYK:
            return comps.count == 4 ? comps : nil
        case .iccBased(let n, _, _):
            if n == 4, comps.count == 4 { return comps }
            if n == 1, let g = comps.first { return [0, 0, 0, 1 - g] }
            return nil
        case .deviceGray, .calGray:
            guard let g = comps.first else { return nil }
            return [0, 0, 0, 1 - g]
        case .indexed:
            return color.resolvedIndexedColor.flatMap { directProcess($0, depth: depth + 1) }
        case .pattern(let base):
            guard let b = base, !comps.isEmpty else { return nil }
            return directProcess(PDFPaintColor(space: b, components: comps), depth: depth + 1)
        default:
            return nil
        }
    }

    /// スウォッチ用の sRGB。CMYK はシミュレーションプロファイル経由。
    static func sRGB(of hit: PDFColorHit, simulation: CGColorSpace) -> NSColor? {
        guard let src = hit.sample?.color ?? hit.color else { return nil }
        return sRGB(of: src, simulation: simulation)
    }

    static func sRGB(of color: PDFPaintColor, simulation: CGColorSpace) -> NSColor? {
        guard let cg = color.cgColor(cmyk: simulation),
              let dst = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = convert(cg, to: dst) else { return nil }
        return NSColor(cgColor: converted)
    }

    /// 相対的な色域マッピング + 黒点補正で変換する
    static func convert(_ color: CGColor, to destination: CGColorSpace) -> CGColor? {
        if let cs = color.colorSpace, cs == destination { return color }
        let options = [CGColor.conversionBlackPointCompensation: kCFBooleanTrue as Any] as CFDictionary
        return color.converted(to: destination, intent: .relativeColorimetric, options: options)
    }

    // MARK: - Separations

    struct Plate {
        let name: String
        var fraction: CGFloat
        let isProcess: Bool
    }

    struct PlatesReadout {
        var plates: [Plate]
        /// 全版の合計 (0–1 の和。表示は ×100 %)
        var tac: CGFloat
        /// プロファイル変換を通した値を含むか
        var isApproximate: Bool
        var note: String?
    }

    /// カーソル位置の分版。`pageSpots` はページ内の特色版名 (出現順)。
    /// 常にプロセス 4 版 + pageSpots の行を返し、当たった色に無い版は 0。
    static func plates(_ hit: PDFColorHit, pageSpots: [String],
                       simulation: CGColorSpace, simulationName: String) -> PlatesReadout? {
        guard let src = hit.sample?.color ?? hit.color else { return nil }

        var process: [CGFloat] = [0, 0, 0, 0]
        var spots: [(String, CGFloat)] = pageSpots.map { ($0, 0) }
        var approximate = false
        var note: String? = nil

        func addSpot(_ name: String, _ value: CGFloat) {
            if let idx = processNames.firstIndex(of: name) {
                process[idx] = max(process[idx], value)
            } else if name == "All" {
                for i in 0..<4 { process[i] = max(process[i], value) }
                for i in spots.indices { spots[i].1 = max(spots[i].1, value) }
                note = "registration color (All)"
            } else if name == "None" {
                return
            } else if let i = spots.firstIndex(where: { $0.0 == name }) {
                spots[i].1 = max(spots[i].1, value)
            } else {
                spots.append((name, value))
            }
        }

        func resolve(_ color: PDFPaintColor, depth: Int) {
            guard depth < 6 else { return }
            let comps = color.components
            switch color.space {
            case .deviceCMYK:
                if comps.count == 4 { process = comps }
            case .iccBased(let n, _, let iccData):
                if n == 4, comps.count == 4 {
                    process = comps
                    if let d = iccData, let desc = NSColorSpace(iccProfileData: d)?.localizedName,
                       desc != simulationName {
                        note = "ICC CMYK (\(desc)) shown as-is, not reseparated"
                    }
                } else if n == 1, let g = comps.first {
                    process[3] = 1 - g
                } else {
                    convertToProcess(color)
                }
            case .deviceGray, .calGray:
                if let g = comps.first { process[3] = 1 - g }
            case .separation(let name, _, _):
                addSpot(name, comps.first ?? 0)
            case .deviceN(let names, _, _):
                for (i, name) in names.enumerated() where i < comps.count {
                    addSpot(name, comps[i])
                }
            case .indexed:
                if let r = color.resolvedIndexedColor { resolve(r, depth: depth + 1) }
            case .pattern(let base):
                if let b = base, !comps.isEmpty {
                    resolve(PDFPaintColor(space: b, components: comps), depth: depth + 1)
                }
            case .unknown:
                break
            default:
                convertToProcess(color)
            }
        }

        func convertToProcess(_ color: PDFPaintColor) {
            guard let cg = color.cgColor(cmyk: simulation),
                  let converted = convert(cg, to: simulation),
                  let c = converted.components, c.count >= 4 else { return }
            process = Array(c.prefix(4))
            approximate = true
        }

        resolve(src, depth: 0)

        var plates = zip(processNames, process).map { Plate(name: $0, fraction: $1, isProcess: true) }
        plates += spots.map { Plate(name: $0.0, fraction: $0.1, isProcess: false) }
        let tac = plates.reduce(0) { $0 + $1.fraction }
        return PlatesReadout(plates: plates, tac: tac, isApproximate: approximate, note: note)
    }

    /// 版のチップ色 (プロセスはシミュレーション空間の単色、特色は tint 100%)
    static func plateChipColor(name: String, spot: CGPDFPageColorScanner.SpotPlate?, simulation: CGColorSpace) -> NSColor? {
        if let idx = processNames.firstIndex(of: name) {
            var comps: [CGFloat] = [0, 0, 0, 0]
            comps[idx] = 1
            return sRGB(of: PDFPaintColor(space: .deviceCMYK, components: comps), simulation: simulation)
        }
        guard let s = spot else { return nil }
        var comps = Array(repeating: CGFloat(0), count: max(s.space.componentCount, 1))
        if s.componentIndex < comps.count { comps[s.componentIndex] = 1 }
        return sRGB(of: PDFPaintColor(space: s.space, components: comps), simulation: simulation)
    }

    static func formatTAC(_ tac: CGFloat) -> String {
        return String(format: "%.0f%%", tac * 100)
    }
}

// MARK: - PDFPaintColor → CGColor

extension PDFPaintColor {

    /// 最も近い CG 色空間で CGColor を作る。CMYK 系は `simulation` の色空間で作る。
    /// Separation / DeviceN は代替色空間へ、Indexed は lookup を引いて再帰。
    func cgColor(cmyk simulation: CGColorSpace, depth: Int = 0) -> CGColor? {
        guard depth < 6 else { return nil }
        let comps = components

        func make(_ cs: CGColorSpace?, _ c: [CGFloat]) -> CGColor? {
            guard let cs = cs, cs.numberOfComponents == c.count else { return nil }
            return CGColor(colorSpace: cs, components: c + [1.0])
        }

        switch space {
        case .deviceGray, .calGray:
            return make(CGColorSpace(name: CGColorSpace.genericGrayGamma2_2), comps)
        case .deviceRGB, .calRGB:
            return make(CGColorSpace(name: CGColorSpace.sRGB), comps)
        case .deviceCMYK:
            return make(simulation, comps)
        case .lab(let range):
            let white: [CGFloat] = [0.9505, 1.0, 1.089]
            return make(CGColorSpace(labWhitePoint: white, blackPoint: nil, range: range), comps)
        case .iccBased(let n, let alternate, let iccData):
            if let data = iccData, let cs = CGColorSpace(iccData: data as CFData), cs.numberOfComponents == comps.count,
               let c = make(cs, comps) {
                return c
            }
            if let alt = alternate {
                return PDFPaintColor(space: alt, components: comps).cgColor(cmyk: simulation, depth: depth + 1)
            }
            switch n {
            case 1: return make(CGColorSpace(name: CGColorSpace.genericGrayGamma2_2), comps)
            case 3: return make(CGColorSpace(name: CGColorSpace.sRGB), comps)
            case 4: return make(simulation, comps)
            default: return nil
            }
        case .indexed:
            return resolvedIndexedColor?.cgColor(cmyk: simulation, depth: depth + 1)
        case .separation, .deviceN:
            return alternateColor?.cgColor(cmyk: simulation, depth: depth + 1)
        case .pattern(let base):
            if let b = base, !comps.isEmpty {
                return PDFPaintColor(space: b, components: comps).cgColor(cmyk: simulation, depth: depth + 1)
            }
            return nil
        case .unknown:
            return nil
        }
    }
}
