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

// Works around a PDFKit regression on macOS 27 (GitHub issue #14).
//
// In the non-continuous display modes (Single Page, Two Pages) PDFKit turns the
// page when a paging key cannot scroll any further: `-[PDFView _scrollVerticalBy:]`
// scrolls, then compares the visible rect before and after and calls
// `goToNextPage:` / `goToPreviousPage:` when nothing moved. Since macOS 27 the
// "after" rect comes from a variant that includes the scroll view's content
// insets while the "before" rect does not, so as soon as the internal scroll view
// carries an inset the two never agree and PDFKit concludes that it has scrolled.
// Under a `.fullSizeContentView` window AppKit insets that scroll view by the
// title-bar height, which is exactly Galley's (and Skim's) situation. The
// continuous modes skip the comparison, and `goToNextPage(_:)` itself still
// works, which is why Space via the menu and the mouse are unaffected.
//
// `keyDownTurningPageIfStuck(with:)` lets PDFKit handle the key first and steps
// in only when a paging key changed neither the page nor the scroll position.
// On a PDFKit that behaves, the fallback never runs.
extension GalleyPDFView {
    private enum PagingDirection {
        case forward
        case backward
    }

    /// The paging direction a key event stands for in PDFKit's own key table,
    /// or nil when the event is not a paging key or the mode does not need help.
    private func pagingDirection(for event: NSEvent) -> PagingDirection? {
        guard displayMode == .singlePage || displayMode == .twoUp else { return nil }
        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else { return nil }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let key = Int(scalar.value)
        switch (key, modifiers) {
        case (0x20, []), (NSPageDownFunctionKey, []),
             (NSDownArrowFunctionKey, []), (NSDownArrowFunctionKey, [.option]):
            return .forward
        case (0x20, [.shift]), (NSPageUpFunctionKey, []),
             (NSUpArrowFunctionKey, []), (NSUpArrowFunctionKey, [.option]):
            return .backward
        default:
            return nil
        }
    }

    /// Passes the key to PDFKit and turns the page itself if PDFKit got stuck.
    func keyDownTurningPageIfStuck(with event: NSEvent) {
        guard let direction = pagingDirection(for: event),
              let clipView = documentView?.enclosingScrollView?.contentView else {
            super.keyDown(with: event)
            return
        }
        let pageBefore = currentPageIndex
        let originBefore = clipView.bounds.origin
        super.keyDown(with: event)
        guard currentPageIndex == pageBefore, clipView.bounds.origin == originBefore else { return }

        switch direction {
        case .forward:
            guard canGoToNextPage else { return }
            goToNextPage(nil)
        case .backward:
            guard canGoToPreviousPage else { return }
            goToPreviousPage(nil)
            // Reading backwards lands on the bottom of the previous page, as
            // PDFKit does when it turns the page itself.
            scrollDocumentViewToBottom()
        }
    }

    private var currentPageIndex: Int? {
        guard let document, let page = currentPage else { return nil }
        return document.index(for: page)
    }

    private func scrollDocumentViewToBottom() {
        guard let docView = documentView,
              let clipView = docView.enclosingScrollView?.contentView,
              docView.bounds.height > clipView.bounds.height else { return }
        var origin = clipView.bounds.origin
        origin.y = docView.isFlipped ? docView.bounds.maxY - clipView.bounds.height : docView.bounds.minY
        let target = clipView.constrainBoundsRect(NSRect(origin: origin, size: clipView.bounds.size)).origin
        clipView.scroll(to: target)
        clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
    }
}
