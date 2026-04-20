// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import AppKit

/// リサイズ時に preferredMaxLayoutWidth を追従させて auto-layout ループを防ぐラベル
final class WrappingLabel: NSTextField {
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if abs(preferredMaxLayoutWidth - newSize.width) > 0.5 {
            preferredMaxLayoutWidth = newSize.width
            invalidateIntrinsicContentSize()
        }
    }
}
