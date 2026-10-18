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
// CMYK シミュレーションプロファイル (Acrobat の出力プレビューの
// 「シミュレーションプロファイル」に相当)。
//
// - 文書に CMYK の /OutputIntents があればそれ
// - 無ければユーザーが選んだインストール済み ICC (UserDefaults に保存)
// - それも無ければ Generic CMYK
//
// CGColorSpace は Sendable でないので、モデルには ICC のバイト列だけを持ち、
// メインアクター側 (ColorDisplaySettings) でキャッシュして作る。
// ==========================================

struct InstalledProfile: Sendable, Hashable {
    let path: String
    let description: String
}

struct SimulationProfile: Sendable {
    enum Source: Sendable {
        case documentIntent
        case installed(path: String)
        case genericCMYK
    }
    let description: String
    /// nil のときは Generic CMYK
    let iccData: Data?
    let source: Source

    static let genericCMYK = SimulationProfile(description: "Generic CMYK", iccData: nil, source: .genericCMYK)
}

enum InstalledProfileCatalog {

    static let userDefaultsKey = "colorPickerSimulationProfilePath"

    static var searchDirectories: [String] {
        let home = NSHomeDirectory()
        return [
            "/System/Library/ColorSync/Profiles",
            "/Library/ColorSync/Profiles",
            "/Library/ColorSync/Profiles/Recommended",
            "/Library/ColorSync/Profiles/Profiles",
            home + "/Library/ColorSync/Profiles",
            "/Library/Application Support/Adobe/Color/Profiles",
            "/Library/Application Support/Adobe/Color/Profiles/Recommended",
        ]
    }

    /// インストール済みの CMYK 出力プロファイルを集める。説明文で重複を除き、説明文順。
    /// 数十ファイルの全読みを伴うので、メインスレッド以外で呼ぶ。
    static func scan() -> [InstalledProfile] {
        let fm = FileManager.default
        var seenPaths = Set<String>()
        var seenDescriptions = Set<String>()
        var out: [InstalledProfile] = []
        for dir in searchDirectories {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items.sorted() {
                let lower = item.lowercased()
                guard lower.hasSuffix(".icc") || lower.hasSuffix(".icm") else { continue }
                let path = dir + "/" + item
                let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
                guard !seenPaths.contains(resolved) else { continue }
                seenPaths.insert(resolved)
                guard headerIsCMYKOutputProfile(path),
                      let data = fm.contents(atPath: path),
                      let desc = description(of: data) else { continue }
                guard !seenDescriptions.contains(desc) else { continue }
                seenDescriptions.insert(desc)
                out.append(InstalledProfile(path: path, description: desc))
            }
        }
        return out.sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
    }

    /// ICC ヘッダ (128 バイト) だけ読んで、色空間が CMYK でクラスが device link でないものに絞る
    private static func headerIsCMYKOutputProfile(_ path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 128), header.count >= 24 else { return false }
        let profileClass = String(decoding: header[12..<16], as: UTF8.self)
        let space = String(decoding: header[16..<20], as: UTF8.self)
        return space == "CMYK" && profileClass != "link"
    }

    /// ICC の説明文 (desc タグ)。CGColorSpace.name は ICC では nil なので NSColorSpace を使う。
    static func description(of data: Data) -> String? {
        guard let cs = CGColorSpace(iccData: data as CFData),
              cs.model == .cmyk, cs.numberOfComponents == 4 else { return nil }
        let name = NSColorSpace(iccProfileData: data)?.localizedName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = name, !n.isEmpty else { return nil }
        return n
    }

    /// 1 ファイルだけ読んでプロファイルにする (起動時の保存値の復元用)
    static func load(path: String) -> SimulationProfile? {
        guard !path.isEmpty,
              let data = FileManager.default.contents(atPath: path),
              let desc = description(of: data) else { return nil }
        return SimulationProfile(description: desc, iccData: data, source: .installed(path: path))
    }

    /// 初期値: Japan Color 2001 Coated があればそれ (全走査はしない)
    static func defaultProfile() -> SimulationProfile {
        for dir in searchDirectories {
            let path = dir + "/JapanColor2001Coated.icc"
            if let p = load(path: path) { return p }
        }
        return .genericCMYK
    }
}

/// Color Picker の表示設定 (表示モード・シミュレーションプロファイル・TAC 上限)。
/// AppDelegate が 1 つ持ち、パネルは `onChange` で再描画する。
@MainActor
final class ColorDisplaySettings {

    static let displayModeKey = "colorPickerDisplayMode"
    static let tacLimitKey = "colorPickerTACLimit"

    var onChange: (() -> Void)?

    var displayMode: ColorDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: ColorDisplaySettings.displayModeKey)
            onChange?()
        }
    }

    /// ユーザーが選んだプロファイル (文書インテントが無いときに使う)
    private(set) var userProfile: SimulationProfile {
        didSet { onChange?() }
    }

    /// 文書の CMYK 出力インテント (あれば最優先)
    var documentIntent: PDFOutputIntent? {
        didSet { onChange?() }
    }

    /// 文書にあるが CMYK でない (PDF/A の sRGB など) インテント。メニューの情報行に使う
    var documentNonCMYKIntent: PDFOutputIntent?

    private(set) var installedProfiles: [InstalledProfile] = []
    private var scanStarted = false

    var tacLimit: Int {
        didSet {
            UserDefaults.standard.set(tacLimit, forKey: ColorDisplaySettings.tacLimitKey)
            onChange?()
        }
    }

    private var cachedSpace: (icc: Data?, space: CGColorSpace)?

    init() {
        let defaults = UserDefaults.standard
        displayMode = ColorDisplayMode(rawValue: defaults.string(forKey: ColorDisplaySettings.displayModeKey) ?? "") ?? .native
        let savedLimit = defaults.integer(forKey: ColorDisplaySettings.tacLimitKey)
        tacLimit = savedLimit > 0 ? savedLimit : 300
        let savedPath = defaults.string(forKey: InstalledProfileCatalog.userDefaultsKey) ?? ""
        if savedPath == SimulationProfile.genericCMYK.description {
            userProfile = .genericCMYK
        } else if let p = InstalledProfileCatalog.load(path: savedPath) {
            userProfile = p
        } else {
            userProfile = InstalledProfileCatalog.defaultProfile()
        }
    }

    // MARK: - Active profile

    var activeProfile: SimulationProfile {
        if let intent = documentIntent, intent.isCMYKProfile {
            return SimulationProfile(description: intent.displayName, iccData: intent.profileData, source: .documentIntent)
        }
        return userProfile
    }

    var simulationName: String { activeProfile.description }

    /// シミュレーション用の CGColorSpace (メインアクター内でキャッシュ)
    var simulationSpace: CGColorSpace {
        let icc = activeProfile.iccData
        if let c = cachedSpace, c.icc == icc { return c.space }
        let space: CGColorSpace
        if let d = icc, let cs = CGColorSpace(iccData: d as CFData), cs.model == .cmyk, cs.numberOfComponents == 4 {
            space = cs
        } else {
            space = CGColorSpace(name: CGColorSpace.genericCMYK) ?? CGColorSpaceCreateDeviceCMYK()
        }
        cachedSpace = (icc, space)
        return space
    }

    // MARK: - User selection

    func selectInstalledProfile(path: String) {
        guard let p = InstalledProfileCatalog.load(path: path) else { return }
        UserDefaults.standard.set(path, forKey: InstalledProfileCatalog.userDefaultsKey)
        userProfile = p
    }

    func selectGenericCMYK() {
        UserDefaults.standard.set(SimulationProfile.genericCMYK.description, forKey: InstalledProfileCatalog.userDefaultsKey)
        userProfile = .genericCMYK
    }

    /// 文書が変わったとき。CMYK のインテントだけを採用し、それ以外は情報として持つ。
    func setDocumentIntents(_ intents: [PDFOutputIntent]) {
        documentNonCMYKIntent = intents.first { !$0.isCMYKProfile }
        documentIntent = CGPDFOutputIntentExtractor.preferredCMYK(intents)
    }

    // MARK: - Installed profile catalog

    /// 初回だけバックグラウンドで走査する。`force` で再走査。
    func scanInstalledProfiles(force: Bool = false) {
        if scanStarted && !force { return }
        scanStarted = true
        Task.detached(priority: .utility) {
            let list = InstalledProfileCatalog.scan()
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.installedProfiles = list
                Log.colorPicker.info("installed CMYK profiles: \(list.count)")
                self.onChange?()
            }
        }
    }
}
