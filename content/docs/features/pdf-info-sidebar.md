+++
title = "PDF Info Sidebar"
weight = 60
+++

# PDF Info Sidebar

Galley exposes a left-hand inspector with five views, each toggled from the
View menu. The sidebar is read-only — it never modifies the PDF — and is
designed for proofreading, preflight, and metadata audits.

| Panel       | Shortcut  | Purpose                                                                 |
|-------------|-----------|--------------------------------------------------------------------------|
| Info        | `Cmd + I` | Document Info, PDF/X, PDF/A, PDF/UA, Security, Pages, Features, Fonts, XMP |
| Bookmarks   | `Cmd + B` | Document outline, click-to-navigate                                      |
| Annotations | `Cmd + N` | All annotations, click-to-navigate; `Cmd + C` copies content             |

## Info panel

The Info panel groups metadata into sections rendered as a key/value list:

- Document Info — Title, Author, Subject, Keywords, Producer, Creator,
  Creation Date, Mod Date, Trapped, plus any custom keys.
- PDF/X, PDF/A, PDF/UA — surfaced from the XMP packet when the document
  declares conformance.
- Security — encryption status, permissions, and version.
- Pages — page count and the MediaBox / CropBox / TrimBox / BleedBox /
  ArtBox of the current page.
- Features — high-level capabilities such as Tagged PDF, Linearized,
  AcroForm, JavaScript, and embedded files.
- Fonts — embedded fonts scanned via `CGPDFDocument`. The scan walks
  inherited page resources and Form XObjects to match `pdffonts` coverage,
  reporting BaseFont, Type, Embedded, Subset, and Encoding for each font.
- XMP — the raw XMP packet parsed via `XMLDocument` and rendered as
  sections, mirroring the layout of Document Info.

## Bookmarks panel

Renders the document outline as a tree. Clicking a bookmark navigates the
PDF view to its target.

## Annotations panel

Lists every annotation in the document with type, page, and body text.
Click a row to jump to the annotation; long FreeText content wraps so that
the full body is visible. Use `Cmd + C` (or the context menu) to copy the
selected annotation's content.

## Export

Sidebar contents can be exported as Markdown or JSON via two equivalent
entry points:

- File ▸ Export ▸ … — submenu items for All, Info, Fonts, XMP, Bookmarks,
  and Annotations, each available as Markdown or JSON. Items whose source
  data is empty are greyed out.
- In-panel Export dropdown — top of the sidebar, copies the active
  panel's content as Markdown or JSON to the clipboard.

The All exports concatenate every panel into one document, suitable for
attaching to a preflight report.
