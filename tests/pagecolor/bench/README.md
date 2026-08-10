# Page Color: cost when off

Page Color was accepted on the condition that turning it off costs
nothing — with `Normal` selected, no layer filters are installed, no
overlay layer is created, no notification observers are registered, and
the document view is never forced to be layer-backed. This directory
holds the evidence for that claim.

## The structural check comes first

Profiling measures a consequence; the invariant itself is cheaper to
verify directly. Attach to a running Galley with `Normal` selected and
confirm, for both `pdfViewA` and `pdfViewB`:

~~~
(lldb) po view.documentView!.layer?.filters          // nil
(lldb) po view.layer?.sublayers?.map { $0.name }     // no GalleyPageColorTint
(lldb) po view.documentView!.wantsLayer              // false, unless something else set it
~~~

If those hold, nothing this feature owns is in the rendering path, and
any measured difference is noise by definition.

## Then the measurement

~~~bash
./run-bench.sh -p /path/to/heavy.pdf
~~~

Builds the current checkout and a pre-feature baseline (default
`7c7dfee`, master before the Page Color merge) into throwaway app
bundles, runs the same workload against each with Page Color forced to
`Normal`, and reports median CPU time and RSS.

Use a genuinely heavy PDF — several hundred pages, or dense vector
figures. If rendering isn't the bottleneck, the benchmark measures
nothing.

Two workloads are available:

- `-m load` (default) launches, waits for the document to render, and
  reads the process's total CPU time. No special permissions needed.
  Measures parsing and first-page rendering.
- `-m keys` additionally sends Page Down through System Events and
  measures only the scrolling, which is where layer filters and overlays
  would show up. Requires Accessibility permission for your terminal.

Note what is *not* here: a `galleypdf://` workload. Both builds carry the
bundle id `com.github.munepi.galley`, so LaunchServices routes those URLs
— and `open -a` — to whichever copy it has registered, usually the
installed `/Applications/GalleyPDF.app`. The script launches the
executable inside the bundle directly instead, which targets the right
build and yields an exact pid.

RSS matters as much as CPU here. The original worry was that forcing
`wantsLayer` on the document view would allocate a large backing store
even when the feature is off; equal memory is what rules that out.

## Result on record

macOS 26.5, M-series, `-m load -n 2`, against a 288-page Japanese book
PDF (`gihyo-planaidd-print_0.5`):

| build | median CPU | median RSS |
|---|---|---|
| baseline `7c7dfee` | 0.67 s | 223.1 MB |
| current, Page Color = Normal | 0.67 s | 217.3 MB |

Identical CPU, and memory equal within run-to-run variation — in
particular no extra backing store, which was the specific worry.

## Reading the result

A difference inside run-to-run noise is the expected outcome. A
consistent gap means something is running that shouldn't be — profile it
with Instruments' Time Profiler and find the caller.

Note that the baseline worktree gets its `Package.swift` linker flag
patched before building: revisions before that fix cannot be linked by
the Swift 6.3 driver. It changes how the binary is linked, not what it
does at runtime.
