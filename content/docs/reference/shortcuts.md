+++
title = "Keyboard Shortcuts"
weight = 10
+++

# Keyboard Shortcuts

| Action                  | Shortcut / Gesture                                                            |
|-------------------------|--------------------------------------------------------------------------------|
| Open File               | `Cmd + O` or `open -a GalleyPDF document.pdf`                                  |
| Print                   | `Cmd + P`                                                                      |
| Find                    | `Cmd + F` (toggle search bar)                                                  |
| Find Next / Previous    | `Cmd + G` / `Shift + Cmd + G` (also `Enter` / `Shift + Enter` while the search bar is focused) |
| Use Selection for Find  | `Cmd + E`                                                                      |
| Zoom In / Out           | `Cmd + +` / `Cmd + -`                                                          |
| Actual Size             | `Cmd + 0`                                                                      |
| Auto Resize             | `Cmd + _`                                                                      |
| Single Page             | `Cmd + 1`                                                                      |
| Single Page Continuous  | `Shift + Cmd + 1`                                                              |
| Two Pages               | `Cmd + 2`                                                                      |
| Two Pages Continuous    | `Shift + Cmd + 2`                                                              |
| Next Page               | `Space`                                                                        |
| Previous Page           | `Shift + Space`                                                                |
| Jump to Page            | Type page number or label (e.g., `123`, `iv`, `cover`)                         |
| Back / Forward          | `Cmd + [` / `Cmd + ]` (navigation history)                                     |
| Clear Selection / Cancel| `Esc`                                                                          |
| Inverse Search          | `Cmd + Click` on PDF                                                           |
| Character Inspection    | Right-click on selected text                                                   |
| Measure / Move / Resize Area | `Shift + Drag` (drag inside marquee to move; drag edges/corners to resize) |
| Copy Selection          | `Cmd + C` (copies as vector PDF)                                               |
| Toggle PDF Info Sidebar | `Cmd + I`                                                                      |
| Toggle PDF Bookmarks Sidebar | `Cmd + B`                                                                 |
| Toggle PDF Annotations Sidebar | `Cmd + N`                                                               |
| Copy Annotation Content | `Cmd + C` (with an Annotations row selected)                                   |

Every one of these is a menu item, and every menu item can be rebound — see
[Custom Key Bindings]({{< relref "key-bindings" >}}).

## Page Navigation & Interface Notes

- Direct Jump: type a page number or label without modifier keys — a
  minimalist HUD appears at the bottom. Input auto-commits after 1 second of
  inactivity.
- Window Title: displays `<FileName> - Page <label> (<physical>/<total>)`
  for a zero-distraction interface.
- Link Preview: hovering over a PDF link for 0.3 s shows a popover with a
  real-size snippet of the target page (internal links) or the URL text
  (external links).
- Navigation History: `Cmd + [` / `Cmd + ]` return to where you were before
  following a link, clicking a bookmark or annotation, jumping to a search
  match, or running a Forward Search — the same keys Preview uses.
- Persistence: Galley remembers Display Mode, Book Mode, RTL, and
  [Page Color]({{< relref "/docs/features/page-color" >}}) settings via
  `UserDefaults`.
