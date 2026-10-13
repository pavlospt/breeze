#!/bin/bash
# Records the README media from the demo tour (sample data, no account needed).
#
# Requires, for the terminal running it:
#   - Screen Recording  (System Settings › Privacy & Security › Screen & System Audio Recording)
#   - Accessibility     (to click the menu bar icon; only for the menu bar clip)
#
# Output: docs/media/{window,menubar}.{gif,mp4} and window-*.png / menubar.png stills.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=docs/media
WORK=.build/demo-recording   # raw .mov files are kept here for picking stills
mkdir -p "$OUT" "$WORK"
APP="$HOME/Applications/Breeze.app"
# The tour idles for 7s after launch, then runs ~26s. Recording starts ~4–5s after launch.
RECORD_SECONDS=31

[ -d "$APP" ] || scripts/build-app.sh

# Prints "x,y,w,h" of the largest on-screen window owned by Breeze at or above `minLayer`.
window_rect() {
  swift - "$1" <<'SWIFT'
import CoreGraphics
let minLayer = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
let best = windows
    .filter { ($0[kCGWindowOwnerName as String] as? String) == "Breeze" && ($0[kCGWindowLayer as String] as? Int ?? 0) >= minLayer }
    .compactMap { w -> CGRect? in
        guard let b = w[kCGWindowBounds as String] as? [String: Double] else { return nil }
        return CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!)
    }
    .filter { $0.width > 200 && $0.height > 200 }
    .max { $0.width * $0.height < $1.width * $1.height }
if let r = best { print("\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))") }
SWIFT
}

launch_tour() {
  pkill -x Breeze 2>/dev/null || true
  sleep 1
  open -n "$APP" --args --demo-tour
  sleep 2.5
}

encode() { # $1 = input .mov, $2 = output basename, $3 = gif width, $4 = start offset (s)
  local trim="-ss $4"
  ffmpeg -loglevel error -y $trim -i "$1" -vf "fps=30,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart "$OUT/$2.mp4"
  # 12 fps, 128 colors and rectangle diffing keep the GIFs small enough for a README.
  ffmpeg -loglevel error -y $trim -i "$1" -vf "fps=12,scale=$3:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    "$OUT/$2.gif"
}

still() { # $1 = input .mov, $2 = timestamp, $3 = output png
  ffmpeg -loglevel error -y -ss "$2" -i "$1" -frames:v 1 "$OUT/$3"
}

# --- Window ---------------------------------------------------------------
echo "Recording window…"
launch_tour
osascript -e 'tell application "Breeze" to activate' >/dev/null 2>&1 || true
RECT=$(window_rect 0)
[ -n "$RECT" ] || { echo "Breeze window not found (is Screen Recording allowed for this terminal?)"; exit 1; }
screencapture -x -v -V "$RECORD_SECONDS" -R "$RECT" "$WORK/window.mov"
encode "$WORK/window.mov" window 760 2
still "$WORK/window.mov" 1.0 window-cool.png
still "$WORK/window.mov" 11 window-heat.png
still "$WORK/window.mov" 17 window-bedroom.png

# --- Menu bar panel ---------------------------------------------------------
echo "Recording menu bar panel…"
launch_tour
osascript -e 'tell application "System Events" to tell process "Breeze" to click menu bar item 1 of menu bar 2'
sleep 0.8
RECT=$(window_rect 1)
[ -n "$RECT" ] || { echo "Menu bar panel not found (is Accessibility allowed for this terminal?)"; exit 1; }
screencapture -x -v -V "$RECORD_SECONDS" -R "$RECT" "$WORK/menubar.mov"
encode "$WORK/menubar.mov" menubar 330 1
still "$WORK/menubar.mov" 1.0 menubar.png

pkill -x Breeze || true

ls -lh "$OUT"
