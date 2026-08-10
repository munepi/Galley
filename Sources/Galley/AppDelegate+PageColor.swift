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
import CoreImage
import PDFKit

// ==========================================
// ページの配色 (アクセシビリティ)
//
// 設計上の不変条件:
//   - .normal のときはレンダリング経路に一切コードを置かない。
//     レイヤフィルタは nil、wantsLayer は立てない、監視も登録しない。
//   - 変換の適用はメニュー操作・書類差し替え・システム設定変更のときだけ。
//     スクロールやページ遷移の経路には何も足さない。
//   - 表示だけに作用させる。コピー・書き出し・印刷は元の色のままにする。
// ==========================================

enum PageColorMode: Int, CaseIterable {
    // raw value は UserDefaults に永続化されるため、既存の値は変更しないこと。
    case normal   = 0
    case dark     = 1
    case sepia    = 2
    case orange   = 3
    case gray     = 4
    case charcoal = 5

    /// メニューでの並び。反転する群と紙を着色するだけの群を区切り線で分ける。
    static let menuGroups: [[PageColorMode]] = [
        [.normal],
        [.dark, .charcoal],
        [.sepia, .orange, .gray],
    ]

    var menuTitle: String {
        switch self {
        case .normal:   return "Normal"
        case .dark:     return "Dark"
        case .charcoal: return "Charcoal"
        case .sepia:    return "Sepia"
        case .orange:   return "Orange"
        case .gray:     return "Gray"
        }
    }

    /// 明暗を入れ替えるモードかどうか。システムの Invert Colors と競合しうる。
    var invertsContent: Bool { self == .dark || self == .charcoal }

    /// 反転モードでの紙の色。`.dark` は PDFKit の既定 (#1E1E1E) に委ねるため nil。
    ///
    /// Charcoal の #2C2C2E は Apple のダークグレー・ランプで #1C1C1E の一段上、
    /// macOS と iOS が浮いた面に使う色。明色インクに対して 11.4:1 で AAA を満たす。
    var darkPaperColor: NSColor? {
        switch self {
        case .charcoal: return NSColor(srgbRed: 0x2C/255.0, green: 0x2C/255.0, blue: 0x2E/255.0, alpha: 1)
        default: return nil
        }
    }

    /// 紙の色。乗算合成で白い紙をこの色に着色する。反転モードでは使わない。
    ///
    /// いずれも黒インクに対する WCAG コントラスト比が AAA (7:1) を大きく上回る。
    /// Sepia 17.8:1 / Orange 18.7:1 / Gray 14.7:1。
    ///
    /// 乗算合成では黒インクが黒のまま残るため、比は紙色の相対輝度 L だけで
    /// (L + 0.05) / 0.05 と決まる。AAA (7:1) の条件は L >= 0.30。
    var paperColor: NSColor? {
        switch self {
        case .sepia:  return NSColor(srgbRed: 0xF4/255.0, green: 0xEC/255.0, blue: 0xD8/255.0, alpha: 1)
        case .orange: return NSColor(srgbRed: 0xFF/255.0, green: 0xF0/255.0, blue: 0xD9/255.0, alpha: 1)
        case .gray:   return NSColor(srgbRed: 0xD8/255.0, green: 0xD8/255.0, blue: 0xD2/255.0, alpha: 1)
        case .normal, .dark, .charcoal: return nil
        }
    }
}

extension AppDelegate {

    static let pageColorDefaultsKey = "pageColorMode"

    /// macOS 26 で PDFKit に入った SPI。Preview.app の
    /// View > Use Dark Appearance for PDF がこれを叩いている。
    /// 文字とベクタだけを反転し、埋め込みラスタ画像は保護される。
    /// 公開ヘッダには無いため、必ず responds(to:) で存在を確かめてから使う。
    private static let setAllowsDarkContentSelector =
        NSSelectorFromString("setAllowsDarkAppearanceContent:")
    private static let allowsDarkContentKey = "allowsDarkAppearanceContent"

    /// 同じ SPI にある紙色の設定子。既定 (未設定) では PDFKit が Apple 準拠の
    /// #1E1E1E を使う。「もう少し薄いダーク」が欲しい人のための隠し設定で、
    /// メニューには出さない。SPI に依存しているので予告なく無くなりうる。
    private static let setDarkPaperSelector =
        NSSelectorFromString("setDarkModeBackgroundColor:")
    private static let darkPaperKey = "darkModeBackgroundColor"
    static let darkPaperDefaultsKey = "pageColorDarkPaper"

    /// `defaults write com.github.munepi.galley pageColorDarkPaper "#303030"`
    ///
    /// 明色インクに対して AAA (7:1) を保つため、相対輝度 0.10 を超える色は
    /// 受け付けず、PDFKit の既定にフォールバックする。
    private static var darkPaperOverride: NSColor? {
        guard let spec = UserDefaults.standard.string(forKey: darkPaperDefaultsKey),
              let color = NSColor(galleyHexString: spec) else { return nil }

        return color.galleyRelativeLuminance <= 0.10 ? color : nil
    }

    var pageColorMode: PageColorMode {
        PageColorMode(rawValue: UserDefaults.standard.integer(forKey: Self.pageColorDefaultsKey)) ?? .normal
    }

    // ------------------------------------------
    // メニュー
    // ------------------------------------------

    @objc func changePageColorMode(_ sender: NSMenuItem) {
        guard let mode = PageColorMode(rawValue: sender.tag) else { return }

        UserDefaults.standard.set(mode.rawValue, forKey: Self.pageColorDefaultsKey)
        self.applyPageColorMode(mode)
    }

    func validatePageColorMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let mode = PageColorMode(rawValue: menuItem.tag) else { return false }

        // システム側の Invert Colors が有効なあいだは二重反転になるため選ばせない。
        // iOS の accessibilityIgnoresInvertColors に相当する API が AppKit には無いので、
        // 状態を読んで自衛するしかない。
        if mode.invertsContent && NSWorkspace.shared.accessibilityDisplayShouldInvertColors {
            menuItem.state = .off
            return false
        }

        menuItem.state = (mode == self.pageColorMode) ? .on : .off
        return true
    }

    // ------------------------------------------
    // 適用
    // ------------------------------------------

    /// 起動時に一度だけ呼ぶ。`.normal` なら何もしない。
    func setupPageColorMode() {
        let mode = self.pageColorMode
        guard mode != .normal else { return }

        self.applyPageColorMode(mode)
    }

    func applyPageColorMode(_ mode: PageColorMode) {
        // リロード時の不整合を防ぐため、A/B両方のビューに反映する
        for view in [pdfViewA, pdfViewB] {
            guard let view = view else { continue }
            Self.apply(mode, to: view)
        }

        self.updatePageColorObservers(for: mode)
    }

    private static func apply(_ mode: PageColorMode, to view: PDFView) {
        let systemInverts = NSWorkspace.shared.accessibilityDisplayShouldInvertColors
        let effective: PageColorMode = (mode.invertsContent && systemInverts) ? .normal : mode

        // まず必ず素の状態に戻す。OFF のときにレンダリング経路へ何も残さないため、
        // 「分岐を挟む」のではなく「経路上からコードを消す」形にしている。
        if view.responds(to: setAllowsDarkContentSelector) {
            view.setValue(false, forKey: allowsDarkContentKey)
        }
        if view.responds(to: setDarkPaperSelector) {
            view.setValue(nil, forKey: darkPaperKey)
        }
        view.appearance = nil
        view.documentView?.layer?.filters = nil
        self.removeTintLayer(from: view)

        guard effective != .normal else { return }

        if effective.invertsContent {
            // SPI は effectiveAppearance が dark でないと no-op になる。
            // ビュー単位で dark を強制すると、システムが Light Mode でも効く。
            view.appearance = NSAppearance(named: .darkAqua)

            if view.responds(to: setAllowsDarkContentSelector) {
                // macOS 26+: PDFKit 自身の実装に委譲する (Preview.app と同じ挙動)。
                // NOTE: BOOL 引数は perform(_:with:) では正しく渡らないため KVC を使う。
                view.setValue(true, forKey: allowsDarkContentKey)

                if view.responds(to: setDarkPaperSelector) {
                    // nil を渡すと PDFKit の既定 (#1E1E1E) に戻る。
                    // 隠し設定は Dark の微調整用なので Charcoal には効かせない。
                    let paper = (effective == .dark) ? self.darkPaperOverride
                                                     : effective.darkPaperColor
                    view.setValue(paper, forKey: darkPaperKey)
                }
            } else {
                // macOS 25 以前へのフォールバック。合成後のピクセルにしか触れないため、
                // 埋め込み画像も反転する (Classic Invert 相当)。また layer.filters は
                // 適用前にレイヤ内容を平坦化するため、ズーム時の文字は SPI より粗い。
                // 紙の濃さも指定できないので、Charcoal は Dark と同じ見え方になる。
                self.setFilters(self.invertFilters(), on: view)
            }
        } else if let paper = effective.paperColor {
            self.addTintLayer(paper, to: view)
        }
    }

    private static func setFilters(_ filters: [CIFilter], on view: PDFView) {
        guard !filters.isEmpty, let documentView = view.documentView else { return }

        // wantsLayer はこの機能が ON のときにだけ立てる。無条件に立てると
        // OFF でも巨大なバッキングストアを抱えることになる。
        documentView.wantsLayer = true
        documentView.layer?.filters = filters
    }

    // ------------------------------------------
    // 紙色 (乗算合成オーバーレイ)
    //
    // layer.filters と違い、乗算合成はコンポジタが毎フレーム最終解像度で行うので
    // レイヤ内容の平坦化が起きず、ズームしても文字がベクタのまま鮮明に保たれる。
    // 白い紙 × 紙色 = 紙色、黒いインク × 紙色 = 黒。
    // CALayer はイベントを受けないため、クリックやスクロールにも影響しない。
    // ------------------------------------------

    private static let tintLayerName = "GalleyPageColorTint"

    private static func addTintLayer(_ color: NSColor, to view: PDFView) {
        // container が layer-backed なので view.layer は暗黙に存在するが、念のため確認
        view.wantsLayer = true
        guard let hostLayer = view.layer,
              let c = color.usingColorSpace(.sRGB) else { return }

        let tint = CALayer()
        tint.name = tintLayerName
        tint.backgroundColor = c.cgColor
        tint.compositingFilter = CIFilter(name: "CIMultiplyBlendMode")
        tint.frame = hostLayer.bounds
        tint.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        tint.zPosition = .greatestFiniteMagnitude
        hostLayer.addSublayer(tint)
    }

    private static func removeTintLayer(from view: PDFView) {
        view.layer?.sublayers?
            .filter { $0.name == tintLayerName }
            .forEach { $0.removeFromSuperlayer() }
    }

    /// 明度を反転しつつ色相を保つ。
    ///
    /// 単純な RGB 反転は色相も 180 度回してしまい、hyperref の青リンクが黄色に、
    /// TikZ の赤がシアンになる。反転後に色相を戻すことで、明暗だけを入れ替える。
    /// (CSS で言う `invert(1) hue-rotate(180deg)` と同じ近似)
    private static func invertFilters() -> [CIFilter] {
        guard let invert = CIFilter(name: "CIColorInvert"),
              let hue = CIFilter(name: "CIHueAdjust") else { return [] }

        hue.setValue(NSNumber(value: Float.pi), forKey: kCIInputAngleKey)
        return [invert, hue]
    }

    // ------------------------------------------
    // 監視 (ON のあいだだけ登録する)
    // ------------------------------------------

    private func updatePageColorObservers(for mode: PageColorMode) {
        NotificationCenter.default.removeObserver(
            self, name: .PDFViewDocumentChanged, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(
            self, name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)

        guard mode != .normal else { return }

        // 書類を差し替えると documentView が作り直され、レイヤフィルタが落ちる。
        NotificationCenter.default.addObserver(
            self, selector: #selector(pageColorDocumentChanged(_:)),
            name: .PDFViewDocumentChanged, object: nil)

        // ユーザが実行中にシステムの Invert Colors を切り替えたときの自衛。
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityDisplayOptionsChanged(_:)),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @objc func pageColorDocumentChanged(_ notification: Notification) {
        guard let view = notification.object as? PDFView,
              view === pdfViewA || view === pdfViewB else { return }

        Self.apply(self.pageColorMode, to: view)
    }

    @objc func accessibilityDisplayOptionsChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            self.applyPageColorMode(self.pageColorMode)
        }
    }
}

private extension NSColor {

    /// "#RRGGBB" / "RRGGBB" を sRGB の色として読む。
    convenience init?(galleyHexString string: String) {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }

        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
                  green: CGFloat((value >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(value & 0xFF) / 255.0,
                  alpha: 1)
    }

    /// WCAG 2.x の相対輝度。コントラスト比 = (明 + 0.05) / (暗 + 0.05)。
    var galleyRelativeLuminance: CGFloat {
        guard let c = self.usingColorSpace(.sRGB) else { return 1 }

        func channel(_ v: CGFloat) -> CGFloat {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(c.redComponent)
             + 0.7152 * channel(c.greenComponent)
             + 0.0722 * channel(c.blueComponent)
    }
}
