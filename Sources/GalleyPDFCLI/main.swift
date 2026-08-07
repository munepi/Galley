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

// ==========================================
// galleypdf — command line front end for Galley
//
// Installed inside the app bundle as
//   GalleyPDF.app/Contents/MacOS/bin/galleypdf
// so Homebrew only has to symlink it onto PATH (the emacsclient layout).
//
// Every subcommand becomes a galleypdf:// URL that is delivered to the bundle
// this executable lives in, so the CLI and the editor integrations documented
// in README.md drive exactly the same handler inside Galley.
// ==========================================

import AppKit

let programName = "galleypdf"

// ==========================================
// 出力とエラー終了
// ==========================================

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(programName): \(message)\n".utf8))
    exit(1)
}

let usage = """
Usage: galleypdf [-g] <file.pdf>
       galleypdf open [-g] [-p PAGE] <file.pdf>
       galleypdf reload
       galleypdf forward [-g] -l LINE [-c COLUMN] [-s SRCFILE] <file.pdf>
       galleypdf displayline [-g] LINE <file.pdf> [SRCFILE]
       galleypdf --app-path | --version | --help

Commands:
  open          Open a PDF in Galley, optionally jumping to a page.
  reload        Force Galley to reload the PDF it is currently showing.
  forward       SyncTeX forward search: jump to the output for a source line.
  displayline   Same as forward, with Skim's displayline argument order.

Options:
  -g, --background   Do not bring Galley to the foreground.
  -p, --page PAGE    Page number to show (1-based, open only).
  -l, --line LINE    Source line number (forward only).
  -c, --column COL   Source column number (forward only).
  -s, --src FILE     TeX source file; defaults to the PDF path with .tex.

Environment:
  GALLEYPDF_APP      Path to the GalleyPDF.app bundle to talk to.
                     Defaults to the bundle containing this executable.
  GALLEYPDF_DRY_RUN  If set, print the galleypdf:// URL instead of sending it.
"""

// ==========================================
// アプリケーションバンドルの解決
//
// Homebrew は PATH 上に symlink を張るだけなので、実行ファイル自身の位置から
// 親方向に .app を探す。argv[0] はシェルが打鍵どおりの文字列を渡すことがあるため、
// 実際の実行パスは Bundle.main.executablePath から取る。
// ==========================================

func resolveAppBundle() -> URL {
    let environment = ProcessInfo.processInfo.environment

    if let override = environment["GALLEYPDF_APP"], !override.isEmpty {
        let url = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            fail("GALLEYPDF_APP does not point at a bundle: \(url.path)")
        }
        return url
    }

    let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
    var url = URL(fileURLWithPath: executable).resolvingSymlinksInPath()
    while url.pathExtension != "app" {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { return fallbackAppBundle() }
        url = parent
    }
    return url
}

func fallbackAppBundle() -> URL {
    let candidates = [
        "/Applications/GalleyPDF.app",
        (NSHomeDirectory() as NSString).appendingPathComponent("Applications/GalleyPDF.app"),
    ]
    guard let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        fail("GalleyPDF.app not found. Set GALLEYPDF_APP to its path.")
    }
    return URL(fileURLWithPath: found)
}

// ==========================================
// URL の組み立て
// ==========================================

// URLComponents.queryItems は値の中の & = + を素通しするため、自前の許可集合で
// パーセントエンコードする。ファイル名にこれらの文字は普通に現れる。
let queryValueAllowed: CharacterSet = {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&=+?#")
    return allowed
}()

struct Request {
    let action: String
    var query: [(name: String, value: String)] = []
    var background = false

    mutating func add(_ name: String, _ value: String) {
        query.append((name, value))
    }

    var url: URL {
        var items = query
        if background { items.append(("background", "1")) }

        var components = URLComponents()
        components.scheme = "galleypdf"
        components.host = action
        if !items.isEmpty {
            components.percentEncodedQuery = items.map { item in
                let encoded = item.value.addingPercentEncoding(withAllowedCharacters: queryValueAllowed)
                return "\(item.name)=\(encoded ?? item.value)"
            }.joined(separator: "&")
        }
        guard let url = components.url else { fail("could not build a galleypdf:// URL") }
        return url
    }
}

// 相対パスは作業ディレクトリ基準で絶対化する。`.` と `..` は URL の初期化時に
// 畳まれるが、それ以上は触らない。standardizedFileURL は /private/tmp を /tmp に
// 書き換えてしまい、SyncTeX が記録したソースパスとの文字列照合が外れる。
func absolutePath(_ path: String) -> String {
    let expanded = (path as NSString).expandingTildeInPath
    let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    return URL(fileURLWithPath: expanded, relativeTo: base).absoluteURL.path
}

func existingPDF(_ path: String?) -> String {
    guard let path, !path.isEmpty else { fail("missing PDF file") }
    let resolved = absolutePath(path)
    guard FileManager.default.fileExists(atPath: resolved) else { fail("no such file: \(path)") }
    return resolved
}

// ==========================================
// 送出
//
// open(1) と同じく、実行ファイルが属するバンドルを名指しして URL を配送する。
// LaunchServices 経由なので Galley が未起動なら起動し、起動済みならその
// インスタンスに届く。
// ==========================================

func dispatch(_ request: Request, to appURL: URL) {
    let url = request.url

    if ProcessInfo.processInfo.environment["GALLEYPDF_DRY_RUN"] != nil {
        print(url.absoluteString)
        return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = !request.background

    let semaphore = DispatchSemaphore(value: 0)
    var dispatchError: Error?
    NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
        dispatchError = error
        semaphore.signal()
    }

    if semaphore.wait(timeout: .now() + 30) == .timedOut {
        fail("timed out waiting for \(appURL.lastPathComponent)")
    }
    if let dispatchError {
        fail(dispatchError.localizedDescription)
    }
}

// ==========================================
// 引数解析
// ==========================================

struct ArgumentReader {
    private var arguments: [String]
    private var index = 0
    /// `--` 以降はオプションとして解釈しない
    private var optionsTerminated = false

    init(_ arguments: [String]) { self.arguments = arguments }

    var isAtEnd: Bool { index >= arguments.count }

    mutating func next() -> String? {
        guard index < arguments.count else { return nil }
        defer { index += 1 }
        return arguments[index]
    }

    /// オプション名を1つ読む。位置引数なら nil を返して読み位置は進めない。
    mutating func nextOption() -> String? {
        guard !optionsTerminated, index < arguments.count else { return nil }
        let argument = arguments[index]
        if argument == "--" {
            optionsTerminated = true
            index += 1
            return nil
        }
        guard argument.hasPrefix("-"), argument.count > 1 else { return nil }
        index += 1
        return argument
    }

    mutating func value(for option: String) -> String {
        // --page=3 形式は呼び出し側で分解済み。ここは分離形のみ。
        guard let value = next() else { fail("\(option) requires a value") }
        return value
    }
}

/// `--page=3` を ("--page", "3") に分解する。
func split(_ option: String) -> (name: String, inlineValue: String?) {
    guard let separator = option.firstIndex(of: "="), option.hasPrefix("--") else {
        return (option, nil)
    }
    return (String(option[option.startIndex..<separator]),
            String(option[option.index(after: separator)...]))
}

// ==========================================
// サブコマンド
// ==========================================

func commandOpen(_ arguments: [String]) -> Request {
    var reader = ArgumentReader(arguments)
    var request = Request(action: "open")
    var page: String?
    var positional: [String] = []

    while !reader.isAtEnd {
        if let option = reader.nextOption() {
            let (name, inline) = split(option)
            switch name {
            case "-g", "-b", "--background": request.background = true
            case "-p", "--page": page = inline ?? reader.value(for: name)
            default: fail("unknown option: \(option)")
            }
        } else if let argument = reader.next() {
            positional.append(argument)
        }
    }

    guard positional.count <= 1 else { fail("too many arguments: \(positional[1])") }
    request.add("pdfpath", existingPDF(positional.first))
    if let page {
        guard Int(page) != nil else { fail("--page requires a number, got: \(page)") }
        request.add("page", page)
    }
    return request
}

func commandReload(_ arguments: [String]) -> Request {
    var reader = ArgumentReader(arguments)
    var request = Request(action: "reload")

    while !reader.isAtEnd {
        if let option = reader.nextOption() {
            switch split(option).name {
            case "-g", "-b", "--background": request.background = true
            default: fail("unknown option: \(option)")
            }
        } else if let argument = reader.next() {
            fail("unexpected argument: \(argument)")
        }
    }
    return request
}

func commandForward(_ arguments: [String]) -> Request {
    var reader = ArgumentReader(arguments)
    var request = Request(action: "forward")
    var line: String?
    var column: String?
    var source: String?
    var positional: [String] = []

    while !reader.isAtEnd {
        if let option = reader.nextOption() {
            let (name, inline) = split(option)
            switch name {
            case "-g", "-b", "--background": request.background = true
            case "-l", "--line": line = inline ?? reader.value(for: name)
            case "-c", "--column": column = inline ?? reader.value(for: name)
            case "-s", "--src": source = inline ?? reader.value(for: name)
            default: fail("unknown option: \(option)")
            }
        } else if let argument = reader.next() {
            positional.append(argument)
        }
    }

    guard positional.count <= 1 else { fail("too many arguments: \(positional[1])") }
    guard let line else { fail("missing --line") }
    guard Int(line) != nil else { fail("--line requires a number, got: \(line)") }

    request.add("line", line)
    if let column {
        guard Int(column) != nil else { fail("--column requires a number, got: \(column)") }
        request.add("column", column)
    }
    request.add("pdfpath", existingPDF(positional.first))
    if let source { request.add("srcpath", absolutePath(source)) }
    return request
}

/// displayline [-g] LINE PDF [SRC] — Skim のヘルパーと同じ引数順。
func commandDisplayline(_ arguments: [String]) -> Request {
    var reader = ArgumentReader(arguments)
    var request = Request(action: "forward")
    var positional: [String] = []

    while !reader.isAtEnd {
        if let option = reader.nextOption() {
            switch split(option).name {
            case "-g", "-b", "-background", "--background": request.background = true
            case "-r", "-revert", "--revert": break  // Skim 互換のため受理して無視
            default: fail("unknown option: \(option)")
            }
        } else if let argument = reader.next() {
            positional.append(argument)
        }
    }

    guard positional.count >= 2 else {
        fail("usage: galleypdf displayline [-g] LINE <file.pdf> [SRCFILE]")
    }
    guard positional.count <= 3 else { fail("too many arguments: \(positional[3])") }
    guard Int(positional[0]) != nil else { fail("LINE must be a number, got: \(positional[0])") }

    request.add("line", positional[0])
    request.add("pdfpath", existingPDF(positional[1]))
    if positional.count == 3 { request.add("srcpath", absolutePath(positional[2])) }
    return request
}

// ==========================================
// エントリポイント
// ==========================================

let arguments = Array(CommandLine.arguments.dropFirst())

guard let first = arguments.first else {
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(1)
}

let rest = Array(arguments.dropFirst())

switch first {
case "-h", "--help", "help":
    print(usage)

case "-V", "--version":
    let appURL = resolveAppBundle()
    guard let version = Bundle(url: appURL)?
        .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
        fail("could not read the version of \(appURL.path)")
    }
    print(version)

case "--app-path":
    print(resolveAppBundle().path)

case "open":
    dispatch(commandOpen(rest), to: resolveAppBundle())

case "reload":
    dispatch(commandReload(rest), to: resolveAppBundle())

case "forward":
    dispatch(commandForward(rest), to: resolveAppBundle())

case "displayline":
    dispatch(commandDisplayline(rest), to: resolveAppBundle())

default:
    // `galleypdf paper.pdf` / `galleypdf -g paper.pdf` は open の省略形
    dispatch(commandOpen(arguments), to: resolveAppBundle())
}
