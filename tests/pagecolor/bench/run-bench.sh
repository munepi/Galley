#!/bin/bash
# Compare Galley's rendering cost with Page Color OFF against a build that
# predates the feature. The claim under test is that selecting `Normal`
# leaves the rendering path as it was, so the two builds should be
# indistinguishable.
#
#   ./run-bench.sh -p /path/to/heavy.pdf
#
# Both builds carry the same bundle id, so `open -a` would hand the launch
# to whichever copy LaunchServices has registered — usually the installed
# /Applications/GalleyPDF.app, not ours. The executable inside the bundle
# is therefore launched directly, which also gives us an exact pid.
#
# For the same reason there is no galleypdf:// workload here: those URLs
# are routed by LaunchServices and would drive the wrong process.
#
# Both builds also share preferences, so pageColorMode is forced to 0
# (Normal) before every trial.
set -euo pipefail

BASELINE_REV="7c7dfee"     # master before the Page Color merge (704f04c)
PDF=""
TRIALS=5
STEPS=40
MODE="load"                # load | keys
SETTLE=6                   # seconds to let a launch finish rendering

usage() {
    cat <<EOF
usage: $0 -p <pdf> [-r <baseline-rev>] [-n <trials>] [-s <steps>] [-m load|keys]

  -p  PDF to open. Use something heavy: a few hundred pages, or dense
      vector figures. The whole point is to make rendering the bottleneck.
  -r  Baseline revision to compare against (default: $BASELINE_REV).
  -n  Trials per build (default: $TRIALS). The median is reported.
  -s  Page Down steps per trial in keys mode (default: $STEPS).
  -m  Workload kind (default: $MODE).
        load  launch, let it parse and render, then read the process's
              total CPU time. Needs no special permissions. Measures
              document loading and first-page rendering.
        keys  additionally sends Page Down through System Events and
              measures the CPU spent scrolling, which is where layer
              filters and overlays would show up. Requires Accessibility
              permission for your terminal, in System Settings >
              Privacy & Security > Accessibility.
EOF
    exit 1
}

while getopts "p:r:n:s:m:h" opt; do
    case "$opt" in
        p) PDF="$OPTARG" ;;
        r) BASELINE_REV="$OPTARG" ;;
        n) TRIALS="$OPTARG" ;;
        s) STEPS="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        *) usage ;;
    esac
done

[ -n "$PDF" ] || usage
[ -f "$PDF" ] || { echo "no such file: $PDF" >&2; exit 1; }
PDF="$(cd "$(dirname "$PDF")" && pwd)/$(basename "$PDF")"
case "$MODE" in load|keys) ;; *) echo "unknown mode: $MODE" >&2; exit 1 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/galley-bench.XXXXXX")"
BASE_WT="$WORK/baseline"

cleanup() {
    git -C "$REPO" worktree remove --force "$BASE_WT" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

# ---------------------------------------------------------------- building

# Assemble the smallest bundle that will actually launch: the binary, the
# generated Info.plist, and Sparkle. No icons, no CLI, no notarization.
build_app() {
    local src="$1" dest="$2" contents="$2/Contents"

    ( cd "$src" && swift build -c release >/dev/null && make Info.plist >/dev/null )

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

median() {
    local places="${1:-2}"
    sort -n | awk -v p="$places" \
        '{ a[NR] = $1 } END { if (NR) printf "%." p "f", a[int((NR + 1) / 2)]; else printf "n/a" }'
}

run_trials() {
    local app="$1" i pid before after rss
    local cpus="" rsss=""

    for i in $(seq 1 "$TRIALS"); do
        defaults write com.github.munepi.galley pageColorMode -int 0

        "$app/Contents/MacOS/GalleyPDF" "$PDF" >/dev/null 2>&1 &
        pid=$!
        sleep "$SETTLE"

        if ! kill -0 "$pid" 2>/dev/null; then
            echo "    trial $i: process exited early" >&2
            continue
        fi

        if [ "$MODE" = "keys" ]; then
            # Measure only the scrolling, with loading already done.
            before="$(cpu_seconds "$pid")"
            osascript "$SCRIPT_DIR/scroll.applescript" "$pid" "$STEPS" >/dev/null
            sleep 1
            after="$(cpu_seconds "$pid")"
        else
            # Everything the process has done: launch, parse, first render.
            before=0
            after="$(cpu_seconds "$pid")"
        fi

        rss="$(ps -p "$pid" -o rss= | tr -d ' ')"
        cpus="$cpus$(awk -v a="$after" -v b="$before" 'BEGIN { printf "%.2f", a - b }')
"
        rsss="$rsss$(awk -v r="$rss" 'BEGIN { printf "%.1f", r / 1024 }')
"
        # Progress goes to stderr so it shows up live rather than being
        # swallowed by the command substitution that collects the summary.
        printf '    trial %d: cpu %ss  rss %sMB\n' "$i" \
            "$(printf '%s' "$cpus" | tail -1)" "$(printf '%s' "$rsss" | tail -1)" >&2

        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        sleep 1
    done

    printf '  median cpu  %ss\n  median rss  %sMB\n' \
        "$(printf '%s' "$cpus" | grep -v '^$' | median 2)" \
        "$(printf '%s' "$rsss" | grep -v '^$' | median 1)"
}

echo
echo "==> pdf:   $PDF"
if [ "$MODE" = "keys" ]; then
    echo "==> mode:  keys, $TRIALS trials x $STEPS steps"
else
    echo "==> mode:  load, $TRIALS trials, ${SETTLE}s settle"
fi
echo
echo "baseline ($BASELINE_REV):"
BASE_RESULT="$(run_trials "$WORK/Baseline.app")"
echo
echo "current (Page Color = Normal):"
CURRENT_RESULT="$(run_trials "$WORK/Current.app")"

echo
echo "================================================================"
echo "baseline ($BASELINE_REV)"
echo "$BASE_RESULT"
echo "current (Page Color = Normal)"
echo "$CURRENT_RESULT"
echo "================================================================"
echo "A difference within run-to-run noise means Normal costs nothing."
echo "A consistent gap means something is running that should not be;"
echo "profile it with Instruments' Time Profiler to find out what."
