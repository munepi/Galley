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

/// 文書カタログの /OutputIntents の 1 項目 (ISO 32000-1 §14.11.5)。
/// Color Picker のシミュレーションプロファイルと Info サイドバーに使う。
struct PDFOutputIntent: Sendable {
    /// /S: "GTS_PDFX", "GTS_PDFA1", "ISO_PDFE1" など
    let subtype: String
    let outputCondition: String?
    let conditionIdentifier: String?
    let info: String?
    let registryName: String?
    /// /DestOutputProfile の ICC バイト列。/DestOutputProfileRef (外部参照) だけのときは nil
    let profileData: Data?
    /// ICC ストリーム辞書の /N
    let components: Int?

    /// 表示名: ICC の説明文 > /OutputCondition > /Info > /OutputConditionIdentifier
    var displayName: String {
        if let d = profileData, let name = NSColorSpace(iccProfileData: d)?.localizedName, !name.isEmpty {
            return name
        }
        return outputCondition ?? info ?? conditionIdentifier ?? subtype
    }

    /// 埋め込みプロファイルが 4 成分の CMYK か (PDF/A の sRGB インテントを除外する)
    var isCMYKProfile: Bool {
        guard let d = profileData, let cs = CGColorSpace(iccData: d as CFData) else { return false }
        return cs.model == .cmyk && cs.numberOfComponents == 4
    }
}

enum CGPDFOutputIntentExtractor {

    static func extract(from document: PDFDocument) -> [PDFOutputIntent] {
        guard let cgDoc = document.documentRef else { return [] }
        return extract(from: cgDoc)
    }

    static func extract(from doc: CGPDFDocument) -> [PDFOutputIntent] {
        guard let catalog = doc.catalog else { return [] }
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(catalog, "OutputIntents", &array), let arr = array else { return [] }

        var intents: [PDFOutputIntent] = []
        for i in 0..<CGPDFArrayGetCount(arr) {
            var dictRef: CGPDFDictionaryRef?
            guard CGPDFArrayGetDictionary(arr, i, &dictRef), let dict = dictRef else { continue }

            let subtype = CGPDFHelpers.name(dict, "S") ?? "?"
            var profileData: Data? = nil
            var components: Int? = nil
            var stream: CGPDFStreamRef?
            if CGPDFDictionaryGetStream(dict, "DestOutputProfile", &stream), let s = stream {
                profileData = CGPDFHelpers.streamData(s)
                if let sd = CGPDFStreamGetDictionary(s) {
                    components = CGPDFHelpers.integer(sd, "N")
                }
            }
            intents.append(PDFOutputIntent(
                subtype: subtype,
                outputCondition: textString(dict, "OutputCondition"),
                conditionIdentifier: textString(dict, "OutputConditionIdentifier"),
                info: textString(dict, "Info"),
                registryName: textString(dict, "RegistryName"),
                profileData: profileData,
                components: components))
        }
        return intents
    }

    /// CMYK シミュレーションに使うインテント。GTS_PDFX > GTS_PDFA1 > ISO_PDFE1 > 先頭の順で、
    /// 4 成分 CMYK のプロファイルが埋め込まれているものだけ。
    static func preferredCMYK(_ intents: [PDFOutputIntent]) -> PDFOutputIntent? {
        let cmyk = intents.filter { $0.isCMYKProfile }
        for s in ["GTS_PDFX", "GTS_PDFA1", "ISO_PDFE1"] {
            if let hit = cmyk.first(where: { $0.subtype == s }) { return hit }
        }
        return cmyk.first
    }

    private static func textString(_ dict: CGPDFDictionaryRef, _ key: String) -> String? {
        var str: CGPDFStringRef?
        guard CGPDFDictionaryGetString(dict, key, &str), let s = str else { return nil }
        guard let cf = CGPDFStringCopyTextString(s) else { return nil }
        let out = cf as String
        return out.isEmpty ? nil : out
    }
}
