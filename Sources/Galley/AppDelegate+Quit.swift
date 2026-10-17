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
// AppDelegate の拡張: Hold ⌘Q to Quit (Chrome と同じ)
// ==========================================
// 組版中の誤打で窓が消えないよう、⌘Q は押し続けたとき、または HUD が出ている間に
// もう一度押したときだけ終了する。
// メニューのクリック、Dock、ログアウト、`osascript quit`、Sparkle の再起動は
// quitAction を通らず NSApp.terminate を直接呼ぶので、従来どおり即終了する。

private enum QuitHold {
    static let defaultsKey = "warnBeforeQuitting"
    /// 終了とみなすまでの押下時間
    static let holdDuration: TimeInterval = 1.0
    /// 途中で離したあと HUD を残しておく時間 (この間にもう一度押せば終了)
    static let lingerDuration: TimeInterval = 1.5
}

extension AppDelegate {

    var warnsBeforeQuitting: Bool {
        return UserDefaults.standard.bool(forKey: QuitHold.defaultsKey)
    }

    @objc func toggleWarnBeforeQuitting(_ sender: Any?) {
        UserDefaults.standard.set(!warnsBeforeQuitting, forKey: QuitHold.defaultsKey)
    }

    @objc func quitAction(_ sender: Any?) {
        // キーボードのメニュー操作 (Return / Space) は修飾キーを伴わないので即終了側に落とす
        let modifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        guard warnsBeforeQuitting,
              let trigger = NSApp.currentEvent, trigger.type == .keyDown,
              !trigger.modifierFlags.intersection(modifierMask).isEmpty else {
            NSApp.terminate(sender)
            return
        }

        // 前回の HUD が残っているうちの 2 回目は、それだけで終了の意思とみなす
        if quitHUD?.isVisible == true {
            Log.app.info("quit confirmed by second press")
            hideQuitHUD(after: 0)
            NSApp.terminate(sender)
            return
        }

        // App Shortcuts で別のキーに割り当てられていても、実際に押されたキーで判定する
        let modifiers = trigger.modifierFlags.intersection(modifierMask)
        showQuitHUD("Hold \(Self.shortcutString(for: trigger, modifiers: modifiers)) to Quit")
        Log.app.info("quit hold started")

        if waitForQuitHold(keyCode: trigger.keyCode, modifiers: modifiers) {
            Log.app.info("quit hold confirmed")
            hideQuitHUD(after: 0)
            NSApp.terminate(sender)
        } else {
            Log.app.info("quit hold cancelled")
            hideQuitHUD(after: QuitHold.lingerDuration)
        }
    }

    /// トリガーのキーと修飾キーが押され続けたら true。Chrome と同じくイベントを直接引いて待つ
    /// (⌘ を押している間の keyUp は NSWindow に届かないため、キューから取る必要がある)。
    private func waitForQuitHold(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let deadline = Date(timeIntervalSinceNow: QuitHold.holdDuration)
        while let event = NSApp.nextEvent(matching: [.keyUp, .keyDown, .flagsChanged],
                                          until: deadline, inMode: .eventTracking, dequeue: true) {
            switch event.type {
            case .keyUp where event.keyCode == keyCode:
                return false
            case .flagsChanged where !event.modifierFlags.contains(modifiers):
                return false
            case .keyDown where !event.isARepeat:
                // 別のキーが押されたら中断し、そのキーは通常どおり処理させる
                NSApp.postEvent(event, atStart: true)
                return false
            default:
                break
            }
        }
        return true
    }

    private static func shortcutString(for event: NSEvent, modifiers: NSEvent.ModifierFlags) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + (event.charactersIgnoringModifiers ?? "").uppercased()
    }

    // ==========================================
    // HUD: 最小化中や Open パネル表示中でも見えるよう、窓とは独立したパネルで出す。
    // 位置は Galley の窓の中央。窓が見えていないときは画面の左右中央・やや上 (NSWindow.center())
    // ==========================================
    private func showQuitHUD(_ message: String) {
        quitHUDHideWorkItem?.cancel()
        quitHUDHideWorkItem = nil

        let panel = quitHUD ?? Self.makeQuitHUDPanel()
        quitHUD = panel

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.sizeToFit()

        let padding = NSSize(width: 36, height: 20)
        let size = NSSize(width: ceil(label.frame.width) + padding.width * 2,
                          height: ceil(label.frame.height) + padding.height * 2)

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 12)
        label.frame.origin = NSPoint(x: padding.width, y: padding.height)
        effect.addSubview(label)
        panel.contentView = effect

        if let window = window, window.isVisible, !window.isMiniaturized {
            let f = window.frame
            panel.setFrame(NSRect(x: f.midX - size.width / 2, y: f.midY - size.height / 2,
                                  width: size.width, height: size.height), display: false)
        } else {
            // 先に Galley の窓がある画面へ置いてから center() で寄せる
            let screen = window?.screen ?? NSScreen.main
            let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
            panel.setFrame(NSRect(origin: NSPoint(x: visible.midX, y: visible.midY), size: size), display: false)
            panel.center()
        }
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
    }

    private func hideQuitHUD(after delay: TimeInterval) {
        quitHUDHideWorkItem?.cancel()
        guard let panel = quitHUD else { return }
        if delay <= 0 {
            panel.orderOut(nil)
            return
        }
        let item = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0.0
            }) {
                // フェード中にもう一度 ⌘Q が押されたら表示し直されているので消さない
                if panel.alphaValue == 0.0 { panel.orderOut(nil) }
            }
        }
        quitHUDHideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private static func makeQuitHUDPanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        // 外観に関わらず暗い HUD にする (showNotification と同じ白文字/黒地)
        panel.appearance = NSAppearance(named: .darkAqua)
        return panel
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
