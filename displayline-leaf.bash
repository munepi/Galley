#!/bin/bash
# Usage: displayline-leaf [-g|--background] LINE PDFFILE [TEXSOURCEFILE]

# Parse options
ACTIVATE="activate"
while [[ "${1:0:1}" == "-" ]]; do
    if [[ "$1" == "-g" || "$1" == "-background" || "$1" == "--background" ]]; then
        ACTIVATE=""
    fi
    shift
  done

if [ $# -lt 2 ]; then
    echo "Usage: displayline-leaf [-g|--background] LINE PDFFILE [TEXSOURCEFILE]"
    exit 1
fi

LINE=$1
PDF=$2
SRC=$3

# Expand relative path to absolute path
[[ "${PDF:0:1}" == "/" ]] || PDF="${PWD}/${PDF}"

# Construct arguments if a source file is specified
if [ -n "$SRC" ]; then
    [[ "${SRC:0:1}" == "/" ]] || SRC="${PWD}/${SRC}"
    # Add as an AppleScript keyword parameter 'srcF'
    SRC_ARG=", «class srcF»:\"${SRC}\""
else
    SRC_ARG=""
fi

# Send custom event 'LFWDfwdj' with named parameters
/usr/bin/osascript << EOF
tell application "LeafPDF"
    ${ACTIVATE}
    «event LFWDfwdj» "${LINE}" given «class pdfP»:"${PDF}"${SRC_ARG}
end tell
EOF
