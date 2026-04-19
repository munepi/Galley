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
| Find Next / Previous    | `Enter` / `Shift + Enter` (while search bar is open)                           |
| Zoom In / Out           | `Cmd + +` / `Cmd + -`                                                          |
| Actual Size             | `Cmd + 0`                                                                      |
| Auto Resize             | `Cmd + _`                                                                      |
| Single Page             | `Cmd + 1`                                                                      |
| Single Page Continuous  | `Shift + Cmd + 1`                                                              |
| Two Pages               | `Cmd + 2`                                                                      |
| Two Pages Continuous    | `Shift + Cmd + 2`                                                              |
| Next Page               | `Space` or `Opt + J`                                                           |
| Previous Page           | `Shift + Space` or `Opt + K`                                                   |
| Jump to Page            | Type page number or label (e.g., `123`, `iv`, `cover`)                         |
| Clear Selection / Cancel| `Esc`                                                                          |
| Inverse Search          | `Cmd + Click` on PDF                                                           |
| Character Inspection    | Right-click on selected text                                                   |
| Measure / Move / Resize Area | `Shift + Drag` (drag inside marquee to move; drag edges/corners to resize) |
| Copy Selection          | `Cmd + C` (copies as vector PDF)                                               |

## Page Navigation & Interface Notes

- Direct Jump: type a page number or label without modifier keys — a
  minimalist HUD appears at the bottom. Input auto-commits after 1 second of
  inactivity.
- Window Title: displays `<FileName> - Page <label> (<physical>/<total>)`
  for a zero-distraction interface.
- Link Preview: hovering over a PDF link for 0.3 s shows a popover with a
  real-size snippet of the target page (internal links) or the URL text
  (external links).
- Persistence: Galley remembers Display Mode, Book Mode, and RTL settings
  via `UserDefaults`.
