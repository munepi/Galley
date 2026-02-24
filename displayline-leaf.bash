#!/bin/bash
# Usage: displayline-leaf [-g|--background] LINE PDFFILE [TEXSOURCEFILE]

# オプションのパース
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

# 相対パスを絶対パスに展開
[[ "${PDF:0:1}" == "/" ]] || PDF="${PWD}/${PDF}"

# ソースファイルが指定されている場合の引数組み立て
if [ -n "$SRC" ]; then
    [[ "${SRC:0:1}" == "/" ]] || SRC="${PWD}/${SRC}"
    # AppleScript のキーワードパラメータ 'srcF' として追加
    SRC_ARG=", «class srcF»:\"${SRC}\""
else
    SRC_ARG=""
fi

# 独自イベント 'LFWDfwdj' に名前付きパラメータを添えて送信
/usr/bin/osascript << EOF
tell application "Leaf"
    ${ACTIVATE}
    «event LFWDfwdj» "${LINE}" given «class pdfP»:"${PDF}"${SRC_ARG}
end tell
EOF
