#!/bin/bash
# Compare Galley's rendering cost with Page Color OFF against a build that
# predates the feature. The claim under test is that selecting `Normal`
# leaves the rendering path byte-for-byte as it was, so the two builds
# should be indistinguishable.
#
#   ./run-bench.sh -p /path/to/heavy.pdf
#
# Both builds share the bundle id, and therefore the same preferences, so
# the script forces pageColorMode to 0 (Normal) before every trial.
set -euo pipefail

BASELINE_REV="7c7dfee"     # master before the Page Color merge (704f04c)
PDF=""
TRIALS=5
STEPS=40
MODE="url"                 # url | keys
PAGES=50                   # page numbers to cycle through in url mode

usage() {
    cat <<EOF
usage: $0 -p <pdf> [-r <baseline-rev>] [-n <trials>] [-s <steps>] [-m url|keys] [-P <pages>]

  -p  PDF to open. Use something heavy: a few hundred pages, or dense
      vector figures. The whole point is to make rendering the bottleneck.
  -r  Baseline revision to compare against (default: $BASELINE_REV).
  -n  Trials per build (default: $TRIALS). The median is reported.
  -s  Workload steps per trial (default: $STEPS).
  -m  Workload kind (default: $MODE).
        url   drives Galley through its own galleypdf:// scheme. Needs no
              special permissions, but each step reloads the document, so
              it weighs document loading as much as compositing.
        keys  sends Page Down through System Events, which exercises
              scrolling and compositing directly. Requires that your
              terminal be granted Accessibility permission in
              System Settings > Privacy & Security > Accessibility.
  -P  Highest page number to jump to in url mode (default: $PAGES).
EOF
    exit 1
}

while getopts "p:r:n:s:m:P:h" opt; do
    case "$opt" in
        p) PDF="$OPTARG" ;;
        r) BASELINE_REV="$OPTARG" ;;
        n) TRIALS="$OPTARG" ;;
        s) STEPS="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        P) PAGES="$OPTARG" ;;
        *) usage ;;
    esac
done

[ -n "$PDF" ] || usage
[ -f "$PDF" ] || { echo "no such file: $PDF" >&2; exit 1; }
PDF="$(cd "$(dirname "$PDF")" && pwd)/$(basename "$PDF")"

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/galley-bench.XXXXXX")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
trap 'cleanup' EXIT

BASE_WT="$WORK/baseline"

cleanup() {
    pkill -f "$WORK/.*/Contents/MacOS/GalleyPDF" 2>/dev/null || true
    git -C "$REPO" worktree remove --force "$BASE_WT" 2>/dev/null || true
    rm -rf "$WORK"
}

# ---------------------------------------------------------------- building

# Assemble the smallest bundle that will actually launch: the binary, the
# generated Info.plist, and Sparkle. No icons, no CLI, no notarization.
build_app() {
    local src="$1" dest="$2"

    ( cd "$src" && swift build -c release >/dev/null && make Info.plist >/dev/null )

    local contents="$dest/Contents"
    mkdir -p "$contents/MacOS" "$contents/Resources" "$contents/Frameworks"
    cp "$src/.build/release/GalleyPDF" "$contents/MacOS/GalleyPDF"
    cp "$src/Info.plist" "$contents/Info.plist"
    rsync -a "$src/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
          "$contents/Frameworks/"
    rm -rf "$contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" \
           "$contents/Frameworks/Sparkle.framework/XPCServices"
    codesign --force -s - "$dest" >/dev/null 2>&1
}

echo "==> preparing baseline ($BASELINE_REV)"
git -C "$REPO" worktree add --detach "$BASE_WT" "$BASELINE_REV" >/dev/null

# Revisions before the -Xlinker fix cannot be linked by the Swift 6.3
# driver. Patch the flag in the throwaway worktree; it changes how the
# binary is linked, not what it does at runtime.
if grep -q -- '-Wl,-rpath' "$BASE_WT/Package.swift"; then
    echo "    patching Package.swift for the current linker driver"
    sed -i '' 's|"-Wl,-rpath,@executable_path/../Frameworks"|"-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"|' \
        "$BASE_WT/Package.swift"
fi

build_app "$BASE_WT" "$WORK/Baseline.app"

echo "==> preparing current ($(git -C "$REPO" rev-parse --short HEAD))"
build_app "$REPO" "$WORK/Current.app"

# ---------------------------------------------------------------- measuring

# ps reports cumulative CPU as [HH:]MM:SS.ss
cpu_seconds() {
    ps -p "$1" -o time= 2>/dev/null | tr -d ' ' | awk -F: '
        NF == 3 { print $1 * 3600 + $2 * 60 + $3; next }
        NF == 2 { print $1 * 60 + $2; next }
        { print 0 }'
}

workload() {
    local pid="$1" step page
    case "$MODE" in
        url)
            for step in $(seq 1 "$STEPS"); do
                page=$(( (step * 7) % PAGES + 1 ))
                open -g "galleypdf://open?pdfpath=${PDF}&page=${page}&background=1"
                sleep 0.2
            done
            ;;
        keys)
            osascript "$SCRIPT_DIR/scroll.applescript" "$pid" "$STEPS"
            ;;
        *) echo "unknown mode: $MODE" >&2; exit 1 ;;
    esac
}

run_trials() {
    local app="$1" label="$2" i pid before after rss
    local -a cpus rsss

    for i in $(seq 1 "$TRIALS"); do
        defaults write com.github.munepi.galley pageColorMode -int 0
        open -a "$app" "$PDF"
        sleep 3   # let the first pages render before the clock starts

        pid="$(pgrep -f "$app/Contents/MacOS/GalleyPDF" | head -1)"
        if [ -z "$pid" ]; then echo "    trial $i: app did not start" >&2; continue; fi

        before="$(cpu_seconds "$pid")"
        workload "$pid"
        sleep 1
        after="$(cpu_seconds "$pid")"
        rss="$(ps -p "$pid" -o rss= | tr -d ' ')"

        # No negative array subscripts: /bin/bash on macOS is still 3.2.
        cpus[${#cpus[@]}]="$(echo "$after $before" | awk '{printf "%.2f", $1 - $2}')"
        rsss[${#rsss[@]}]="$(echo "$rss" | awk '{printf "%.1f", $1 / 1024}')"
        printf '    trial %d: cpu %ss  rss %sMB\n' \
            "$i" "${cpus[$((${#cpus[@]} - 1))]}" "${rsss[$((${#rsss[@]} - 1))]}"

        kill "$pid" 2>/dev/null || true
        sleep 1
    done

    printf '%s\n' "$label" \
        "$(printf '%s\n' "${cpus[@]}"  | sort -n | awk '{a[NR]=$1} END {printf "  median cpu  %.2fs", a[int((NR+1)/2)]}')" \
        "$(printf '%s\n' "${rsss[@]}" | sort -n | awk '{a[NR]=$1} END {printf "  median rss  %.1fMB", a[int((NR+1)/2)]}')"
}

echo
echo "==> pdf:   $PDF"
echo "==> mode:  $MODE, $TRIALS trials x $STEPS steps"
echo
echo "baseline:"
BASE_RESULT="$(run_trials "$WORK/Baseline.app" "baseline ($BASELINE_REV)")"
echo
echo "current:"
CURRENT_RESULT="$(run_trials "$WORK/Current.app" "current (Page Color = Normal)")"

echo
echo "================================================================"
echo "$BASE_RESULT"
echo "$CURRENT_RESULT"
echo "================================================================"
echo "A difference within run-to-run noise means Normal costs nothing."
echo "A consistent gap means something is running that should not be;"
echo "profile it with Instruments' Time Profiler to find out what."
