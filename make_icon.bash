#!/bin/bash
set -euxo pipefail
cd "$(dirname "$0")/"

# $ file GalleyPDF.png
# GalleyPDF.png: PNG image data, 2048 x 2048, 8-bit/color RGBA, non-interlaced

# Create the iconset directory and generate images of various sizes (using sips)
mkdir GalleyPDF.iconset
sips -z 16 16     GalleyPDF.png --out GalleyPDF.iconset/icon_16x16.png > /dev/null
sips -z 32 32     GalleyPDF.png --out GalleyPDF.iconset/icon_16x16@2x.png > /dev/null
sips -z 32 32     GalleyPDF.png --out GalleyPDF.iconset/icon_32x32.png > /dev/null
sips -z 64 64     GalleyPDF.png --out GalleyPDF.iconset/icon_32x32@2x.png > /dev/null
sips -z 128 128   GalleyPDF.png --out GalleyPDF.iconset/icon_128x128.png > /dev/null
sips -z 256 256   GalleyPDF.png --out GalleyPDF.iconset/icon_128x128@2x.png > /dev/null
sips -z 256 256   GalleyPDF.png --out GalleyPDF.iconset/icon_256x256.png > /dev/null
sips -z 512 512   GalleyPDF.png --out GalleyPDF.iconset/icon_256x256@2x.png > /dev/null
sips -z 512 512   GalleyPDF.png --out GalleyPDF.iconset/icon_512x512.png > /dev/null
sips -z 1024 1024 GalleyPDF.png --out GalleyPDF.iconset/icon_512x512@2x.png > /dev/null

# Compile into an .icns file
iconutil -c icns GalleyPDF.iconset

# Clean up temporary files
rm -rf GalleyPDF.iconset

echo "✅ GalleyPDF.icns generated successfully!"
