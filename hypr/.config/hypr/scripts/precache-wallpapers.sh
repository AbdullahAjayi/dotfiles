#!/bin/bash

# =============================================================================
# Wallpaper Pre-Analyzer (matches apply-theme.sh v4.0)
# Runs at login in background. Pre-computes color data for every wallpaper
# so apply-theme.sh can skip the slow analysis and apply instantly.
# Safe to re-run — skips wallpapers already cached.
# =============================================================================

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WAL_DIR="$HOME/.cache/wal"
PRECOMPUTED="$WAL_DIR/precomputed"

mkdir -p "$PRECOMPUTED"

# ── Helpers ──────────────────────────────────────────────────────────────────

_contrast() {
    local img=$1 x=$2 w=$3
    local hex lum
    hex=$(magick "$img" -crop "${w}x10%+${x}+0" -resize 1x1! txt: \
          | grep -o '#[0-9A-F]\{6\}' | head -1)
    lum=$(magick xc:"$hex" -colorspace Gray -format "%[fx:u]" info:)
    python3 -c "print('#000000' if $lum > 0.52 else '#ffffff')"
}

# ── Main loop ─────────────────────────────────────────────────────────────────

# Use an isolated cache directory for pywal so we don't overwrite the live theme!
ISOLATED_CACHE=$(mktemp -d)
export XDG_CACHE_HOME="$ISOLATED_CACHE"
ISOLATED_WAL="$ISOLATED_CACHE/wal"

mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))

total=${#wallpapers[@]}
done=0

echo "[precache] $total wallpapers to check."

for wp in "${wallpapers[@]}"; do
    KEY=$(basename "$wp" | sed 's/\.[^.]*$//')
    CACHE="$PRECOMPUTED/$KEY"

    # Skip if already cached
    if [[ -f "$CACHE/ui.env" && -d "$CACHE/wal" ]]; then
        ((done++)); continue
    fi

    echo "[precache] [$((done+1))/$total] $KEY"
    mkdir -p "$CACHE/wal"

    # Brightness → light/dark
    brightness=$(magick "$wp" -colorspace Gray -resize 1x1! -format "%[fx:u]" info:)
    is_light=$(python3 -c "print('yes' if $brightness > 0.58 else 'no')")
    if [[ "$is_light" == "yes" ]]; then
        WAL_MODE="-l"; GTK_SCHEME="prefer-light"; THEME_NAME="light"
    else
        WAL_MODE=""; GTK_SCHEME="prefer-dark"; THEME_NAME="dark"
    fi

    # Run pywal in isolated cache
    wal -i "$wp" -n $WAL_MODE --saturate 0.8 -q 2>/dev/null

    # Cache ALL wal output files from isolated cache
    find "$ISOLATED_WAL" -maxdepth 1 -type f -exec cp {} "$CACHE/wal/" \;

    # Python UI extraction (using isolated colors)
    TMP_ENV=$(mktemp)
    python3 > "$TMP_ENV" << PYEOF
import colorsys

def hex_to_rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i+2], 16)/255.0 for i in (0, 2, 4)]

def rgb_to_hex(rgb):
    return '#%02x%02x%02x' % tuple(int(min(max(c,0),1)*255) for c in rgb)

with open('$ISOLATED_WAL/colors') as f:
    raw = [l.strip() for l in f]

raw_bg, accents = raw[0], raw[1:7]
r, g, b = hex_to_rgb(raw_bg)
h, s, v = colorsys.rgb_to_hsv(r, g, b)

if '$GTK_SCHEME' == 'prefer-dark':
    v = min(v, 0.06); s = min(s, 0.15)
    fg_final = '#eeeeee'
    bar_bg = 'rgba(30,30,30,0.75)' if v < 0.15 else 'rgba(0,0,0,0.4)'
else:
    v = max(v, 0.98); s = min(s, 0.05)
    fg_final = '#111111'
    bar_bg = 'rgba(255,255,255,0.4)'

bg_final = rgb_to_hex(colorsys.hsv_to_rgb(h, s, v))

def score(c):
    hh, ss, vv = colorsys.rgb_to_hsv(*hex_to_rgb(c))
    return ss * 1.5 + vv

accent = max(accents, key=score)
ar, ag, ab = hex_to_rgb(accent)
ah, asat, av = colorsys.rgb_to_hsv(ar, ag, ab)
if '$GTK_SCHEME' == 'prefer-dark':
    av = max(av, 0.8); asat = max(asat, 0.5)
else:
    av = min(av, 0.4); asat = max(asat, 0.6)
accent_text = rgb_to_hex(colorsys.hsv_to_rgb(ah, asat, av))

yaru = {'blue':210,'green':120,'red':0,'yellow':60,'magenta':300,
        'purple':270,'olive':70,'sage':100,'prussiangreen':170}
icon_v = min(yaru, key=lambda k: min(abs(ah*360-yaru[k]), 360-abs(ah*360-yaru[k])))

print(f'BG="{bg_final}"')
print(f'FG="{fg_final}"')
print(f'ACCENT="{accent}"')
print(f'ACCENT_TEXT="{accent_text}"')
print(f'BAR_BG="{bar_bg}"')
print(f'ICON_VARIANT="{icon_v}"')
PYEOF
    source "$TMP_ENV"
    rm -f "$TMP_ENV"

    # Waybar contrast
    W=$(magick identify -format "%w" "$wp")
    T=$((W / 3))
    L_TEXT=$(_contrast "$wp" 0        $T)
    C_TEXT=$(_contrast "$wp" $T       $T)
    R_TEXT=$(_contrast "$wp" $((T*2)) $T)

    # Save ui.env
    cat > "$CACHE/ui.env" << ENVEOF
BG="$BG"
FG="$FG"
ACCENT="$ACCENT"
ACCENT_TEXT="$ACCENT_TEXT"
BAR_BG="$BAR_BG"
ICON_VARIANT="$ICON_VARIANT"
L_TEXT="$L_TEXT"
C_TEXT="$C_TEXT"
R_TEXT="$R_TEXT"
GTK_SCHEME="$GTK_SCHEME"
THEME_NAME="$THEME_NAME"
WAL_MODE="$WAL_MODE"
ENVEOF

    ((done++))
    echo "[precache] ✓ $KEY"
    sleep 0.5  # Don't hammer CPU at login
done

# Cleanup isolated cache
rm -rf "$ISOLATED_CACHE"

echo "[precache] Done — $done/$total cached."
