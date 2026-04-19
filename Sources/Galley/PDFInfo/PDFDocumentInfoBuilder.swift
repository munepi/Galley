// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Munehiro Yamamoto <munepixyz@gmail.com>
// All rights reserved.

import Foundation
import PDFKit

enum PDFDocumentInfoBuilder {

    static func build(document: PDFDocument?, url: URL?) -> PDFDocumentInfo {
        guard let doc = document else { return .empty }
        var sections: [InfoSection] = []
        sections.append(buildFileSection(document: doc, url: url))
        sections.append(buildDocumentInfoSection(document: doc))
        sections.append(contentsOf: extractComplianceSections(from: doc))
        sections.append(buildSecuritySection(document: doc))
        sections.append(buildPagesSection(document: doc))
        sections.append(buildFeaturesSection(document: doc))
        return PDFDocumentInfo(sections: sections)
    }

    // MARK: - File

    private static func buildFileSection(document: PDFDocument, url: URL?) -> InfoSection {
        var rows: [InfoRow] = []
        if let url = url {
            rows.append(.keyValue(key: "Path", value: url.path))
            rows.append(.keyValue(key: "File Name", value: url.lastPathComponent))
            if let size = fileSize(at: url) {
                rows.append(.keyValue(key: "File Size", value: formatFileSize(size)))
            }
        } else {
            rows.append(.keyValue(key: "Path", value: "(not saved)"))
        }
        let major = document.majorVersion
        let minor = document.minorVersion
        rows.append(.keyValue(key: "PDF Version", value: "\(major).\(minor)"))
        return InfoSection(id: .file, title: "File", rows: rows)
    }

    private static func fileSize(at url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return size.int64Value
    }

    private static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        let human = formatter.string(fromByteCount: bytes)
        let grouped = NumberFormatter.localizedString(from: NSNumber(value: bytes), number: .decimal)
        return "\(human) (\(grouped) bytes)"
    }

    // MARK: - Document Info (/Info dictionary)

    private static let docInfoKeyOrder: [(String, String)] = [
        (PDFDocumentAttribute.titleAttribute.rawValue, "Title"),
        (PDFDocumentAttribute.authorAttribute.rawValue, "Author"),
        (PDFDocumentAttribute.subjectAttribute.rawValue, "Subject"),
        (PDFDocumentAttribute.keywordsAttribute.rawValue, "Keywords"),
        (PDFDocumentAttribute.creatorAttribute.rawValue, "Creator"),
        (PDFDocumentAttribute.producerAttribute.rawValue, "Producer"),
        (PDFDocumentAttribute.creationDateAttribute.rawValue, "Creation Date"),
        (PDFDocumentAttribute.modificationDateAttribute.rawValue, "Modification Date"),
    ]

    private static func buildDocumentInfoSection(document: PDFDocument) -> InfoSection {
        var rows: [InfoRow] = []
        let attrs = document.documentAttributes ?? [:]
        var seenKeys = Set<String>()
        for (rawKey, label) in docInfoKeyOrder {
            seenKeys.insert(rawKey)
            let value = attrs[rawKey].map { formatAttributeValue($0) } ?? "—"
            rows.append(.keyValue(key: label, value: value))
        }
        // 未知キーも追加
        for (key, value) in attrs {
            let keyStr: String
            if let k = key as? String {
                keyStr = k
            } else {
                keyStr = "\(key)"
            }
            if seenKeys.contains(keyStr) { continue }
            rows.append(.keyValue(key: keyStr, value: formatAttributeValue(value)))
        }
        return InfoSection(id: .documentInfo, title: "Document Info", rows: rows)
    }

    private static func formatAttributeValue(_ value: Any) -> String {
        if let date = value as? Date {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: date)
        }
        if let arr = value as? [Any] {
            return arr.map { "\($0)" }.joined(separator: ", ")
        }
        if let s = value as? String {
            return s.isEmpty ? "—" : s
        }
        return "\(value)"
    }

    // MARK: - PDF/X, PDF/A, PDF/UA compliance (XMP 由来)

    private static let complianceTitles: Set<String> = ["PDF/X", "PDF/A", "PDF/UA"]

    private static func extractComplianceSections(from doc: PDFDocument) -> [InfoSection] {
        let xmp = CGPDFMetadataExtractor.extract(from: doc)
        guard let xml = xmp.xml else { return [] }
        let parsed = XMPParser.parse(xml)
        return parsed.sections.filter { complianceTitles.contains($0.title) }
    }

    // MARK: - Security

    private static func buildSecuritySection(document: PDFDocument) -> InfoSection {
        var rows: [InfoRow] = []
        rows.append(.keyValue(key: "Encrypted", value: document.isEncrypted ? "Yes" : "No"))
        rows.append(.keyValue(key: "Locked", value: document.isLocked ? "Yes" : "No"))
        rows.append(.keyValue(key: "Allows Printing", value: yn(document.allowsPrinting)))
        rows.append(.keyValue(key: "Allows Copying", value: yn(document.allowsCopying)))
        rows.append(.keyValue(key: "Allows Commenting", value: yn(document.allowsCommenting)))
        rows.append(.keyValue(key: "Allows Content Accessibility", value: yn(document.allowsContentAccessibility)))
        rows.append(.keyValue(key: "Allows Document Changes", value: yn(document.allowsDocumentChanges)))
        rows.append(.keyValue(key: "Allows Document Assembly", value: yn(document.allowsDocumentAssembly)))
        rows.append(.keyValue(key: "Allows Form Field Entry", value: yn(document.allowsFormFieldEntry)))
        return InfoSection(id: .security, title: "Security", rows: rows)
    }

    private static func yn(_ b: Bool) -> String { b ? "Yes" : "No" }

    // MARK: - Pages

    private static func buildPagesSection(document: PDFDocument) -> InfoSection {
        var rows: [InfoRow] = []
        rows.append(.keyValue(key: "Page Count", value: "\(document.pageCount)"))

        // 全ページのサイズが同じなら1行、異なるなら最初の数ページを列挙
        var sizes: [(CGSize, Int)] = []  // unique size, rotation
        var allSame = true
        var firstSize: CGSize?
        var firstRot: Int = 0
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let rot = page.rotation
            if firstSize == nil {
                firstSize = bounds.size
                firstRot = rot
                sizes.append((bounds.size, rot))
            } else if bounds.size != firstSize || rot != firstRot {
                allSame = false
                if !sizes.contains(where: { $0.0 == bounds.size && $0.1 == rot }) {
                    sizes.append((bounds.size, rot))
                }
            }
            if sizes.count > 5 { break }
        }

        if allSame, let s = firstSize {
            rows.append(.keyValue(key: "Page Size", value: formatPageSize(s)))
            rows.append(.keyValue(key: "Rotation", value: "\(firstRot)°"))
        } else {
            for (i, item) in sizes.enumerated() {
                rows.append(.keyValue(key: "Page Size #\(i + 1)", value: "\(formatPageSize(item.0)), \(item.1)°"))
            }
            if sizes.count > 5 {
                rows.append(.keyValue(key: "…", value: "more sizes not shown"))
            }
        }

        return InfoSection(id: .pages, title: "Pages", rows: rows)
    }

    private static func formatPageSize(_ size: CGSize) -> String {
        let mmW = size.width * 25.4 / 72.0
        let mmH = size.height * 25.4 / 72.0
        return String(format: "%.3f × %.3f pt  (%.1f × %.1f mm)", size.width, size.height, mmW, mmH)
    }

    // MARK: - Features

    private static func buildFeaturesSection(document: PDFDocument) -> InfoSection {
        var rows: [InfoRow] = []
        rows.append(.keyValue(key: "Outlines (Bookmarks)", value: yn(document.outlineRoot != nil)))

        // Annotations: いずれかのページに存在すれば Yes
        var hasAnnots = false
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), !page.annotations.isEmpty {
                hasAnnots = true
                break
            }
        }
        rows.append(.keyValue(key: "Annotations", value: yn(hasAnnots)))

        // CGPDFDocument 経由でのチェック
        if let cg = document.documentRef {
            rows.append(.keyValue(key: "Tagged PDF", value: yn(isTaggedPDF(cg))))
            rows.append(.keyValue(key: "AcroForm", value: yn(hasAcroForm(cg))))
            rows.append(.keyValue(key: "JavaScript", value: yn(hasJavaScript(cg))))
        }

        return InfoSection(id: .features, title: "Features", rows: rows)
    }

    private static func isTaggedPDF(_ doc: CGPDFDocument) -> Bool {
        guard let catalog = doc.catalog else { return false }
        var markInfo: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(catalog, "MarkInfo", &markInfo),
              let mi = markInfo else { return false }
        var marked: CGPDFBoolean = 0
        return CGPDFDictionaryGetBoolean(mi, "Marked", &marked) && marked != 0
    }

    private static func hasAcroForm(_ doc: CGPDFDocument) -> Bool {
        guard let catalog = doc.catalog else { return false }
        var form: CGPDFDictionaryRef?
        return CGPDFDictionaryGetDictionary(catalog, "AcroForm", &form)
    }

    private static func hasJavaScript(_ doc: CGPDFDocument) -> Bool {
        guard let catalog = doc.catalog else { return false }
        var names: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(catalog, "Names", &names),
              let n = names else { return false }
        var js: CGPDFDictionaryRef?
        return CGPDFDictionaryGetDictionary(n, "JavaScript", &js)
    }
}
