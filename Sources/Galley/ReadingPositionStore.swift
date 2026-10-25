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

import CryptoKit
import Foundation

// ==========================================
// 文書ごとの最後の表示位置 (Issue #15)
// ==========================================
// PDF の横にサイドカーファイルを置かず、Application Support 下の 1 枚のバイナリ plist にまとめる。
// UserDefaults は set のたびに値全体を書き直すため使わない。
// 書き込みはページ送りのたびではなく、文書を離れるときと終了時だけ。
//
// 主キーはパス。TeX 文書は再コンパイルでバイト列が変わるので、内容ハッシュ (SHA-256) は
// パスで見つからなかったとき (移動・改名・コピー) のフォールバックにだけ使う。
// どちらで見つけてもページ数が一致しなければ使わない (再コンパイルで組み替わった、別の文書)。

@MainActor final class ReadingPositionStore {

    struct Entry: Codable {
        var pageCount: Int
        var pageIndex: Int
        /// ページ内の位置 (PDFDestination.point、ページ座標)
        var pointX: Double
        var pointY: Double
        var autoScales: Bool
        var scaleFactor: Double
        /// 大きすぎるファイルではハッシュを取らない (nil)
        var sha256: String?
        /// ハッシュを取り直すかどうかの判定用
        var fileSize: Int64
        var modificationDate: Date
        /// LRU の刈り込み用
        var lastUsed: Date
    }

    /// これを超えた分は古いものから捨てる
    static let maxEntries = 2_000
    /// これより大きいファイルはハッシュを取らず、パスだけで追う (終了時に待たせないため)
    static let maxHashedFileSize: Int64 = 512 * 1024 * 1024

    private let storeURL: URL
    private var entries: [String: Entry] = [:]
    private var isLoaded = false
    private var isDirty = false

    init(storeURL: URL = ReadingPositionStore.defaultStoreURL) {
        self.storeURL = storeURL
    }

    nonisolated static var defaultStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let bundleID = Bundle.main.bundleIdentifier ?? "com.github.munepi.galley"
        return base.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("ReadingPositions.plist")
    }

    static func key(for url: URL) -> String {
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// 開いた文書に使える記録を返す。ページ数が違えば nil。
    func entry(for url: URL, pageCount: Int) -> Entry? {
        loadIfNeeded()

        // パスで見つかったら、ページ数が違ってもハッシュには行かない (同じ場所で組み替わった文書)
        if let entry = entries[Self.key(for: url)] {
            return entry.pageCount == pageCount ? entry : nil
        }

        guard let hash = Self.sha256(of: url) else { return nil }
        let match = entries.values
            .filter { $0.sha256 == hash && $0.pageCount == pageCount }
            .max { $0.lastUsed < $1.lastUsed }
        if match != nil {
            Log.file.info("readingPosition: matched \(url.lastPathComponent, privacy: .public) by content hash")
        }
        return match
    }

    func record(url: URL, pageCount: Int, pageIndex: Int, point: CGPoint,
                autoScales: Bool, scaleFactor: CGFloat) {
        loadIfNeeded()

        let key = Self.key(for: url)
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let modificationDate = attributes?[.modificationDate] as? Date ?? .distantPast

        // 前回から中身が変わっていなければハッシュを使い回す
        let hash: String?
        if let previous = entries[key],
           previous.fileSize == fileSize, previous.modificationDate == modificationDate {
            hash = previous.sha256
        } else {
            hash = Self.sha256(of: url)
        }

        entries[key] = Entry(pageCount: pageCount, pageIndex: pageIndex,
                             pointX: Double(point.x), pointY: Double(point.y),
                             autoScales: autoScales, scaleFactor: Double(scaleFactor),
                             sha256: hash, fileSize: fileSize,
                             modificationDate: modificationDate, lastUsed: Date())
        isDirty = true
    }

    func saveIfNeeded() {
        guard isDirty else { return }

        if entries.count > Self.maxEntries {
            let kept = entries.sorted { $0.value.lastUsed > $1.value.lastUsed }.prefix(Self.maxEntries)
            entries = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }

        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(entries)
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: storeURL, options: .atomic)
            isDirty = false
        } catch {
            Log.file.error("readingPosition: save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard let data = try? Data(contentsOf: storeURL) else { return }
        do {
            entries = try PropertyListDecoder().decode([String: Entry].self, from: data)
        } catch {
            // 壊れていたら空から始める (次の保存で上書きされる)
            Log.file.error("readingPosition: load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func sha256(of url: URL) -> String? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value,
              size <= maxHashedFileSize,
              let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
