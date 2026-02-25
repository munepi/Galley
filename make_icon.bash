#!/bin/bash
set -euxo pipefail
cd "$(dirname "$0")/"

#!/bin/bash

cat << 'EOF' > make_icon.swift
import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// 1. Fill the background with a white squircle (standard macOS Big Sur+ style)
let rect = NSRect(origin: .zero, size: size)
let path = NSBezierPath(roundedRect: rect, xRadius: 224, yRadius: 224)
NSColor.white.setFill()
path.fill()

// 2. Draw the 🌿 emoji
let emoji = "🌿"
let font = NSFont.systemFont(ofSize: 760)
let attrs: [NSAttributedString.Key: Any] = [.font: font]
let stringSize = emoji.size(withAttributes: attrs)
let drawRect = NSRect(
    x: (size.width - stringSize.width) / 2,
    y: (size.height - stringSize.height) / 2 - 40, // Fine-tune vertical alignment
    width: stringSize.width,
    height: stringSize.height
)
emoji.draw(in: drawRect, withAttributes: attrs)

image.unlockFocus()

// 3. Export as PNG
if let tiff = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff),
   let png = bitmap.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "icon_1024.png"))
}
EOF

# Run the Swift script to generate a 1024x1024 PNG
swift make_icon.swift

# Create the iconset directory and generate images of various sizes (using sips)
mkdir LeafPDF.iconset
sips -z 16 16     icon_1024.png --out LeafPDF.iconset/icon_16x16.png > /dev/null
sips -z 32 32     icon_1024.png --out LeafPDF.iconset/icon_16x16@2x.png > /dev/null
sips -z 32 32     icon_1024.png --out LeafPDF.iconset/icon_32x32.png > /dev/null
sips -z 64 64     icon_1024.png --out LeafPDF.iconset/icon_32x32@2x.png > /dev/null
sips -z 128 128   icon_1024.png --out LeafPDF.iconset/icon_128x128.png > /dev/null
sips -z 256 256   icon_1024.png --out LeafPDF.iconset/icon_128x128@2x.png > /dev/null
sips -z 256 256   icon_1024.png --out LeafPDF.iconset/icon_256x256.png > /dev/null
sips -z 512 512   icon_1024.png --out LeafPDF.iconset/icon_256x256@2x.png > /dev/null
sips -z 512 512   icon_1024.png --out LeafPDF.iconset/icon_512x512.png > /dev/null
sips -z 1024 1024 icon_1024.png --out LeafPDF.iconset/icon_512x512@2x.png > /dev/null

# Compile into an .icns file
iconutil -c icns LeafPDF.iconset

# Clean up temporary files
rm -rf make_icon.swift icon_1024.png LeafPDF.iconset

echo "✅ LeafPDF.icns generated successfully!"
