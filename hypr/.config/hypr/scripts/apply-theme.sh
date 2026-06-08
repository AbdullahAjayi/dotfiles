#!/bin/bash

# =============================================================================
# Adaptive Theme Engine v4.0
# Architecture: Analyze/Cache → Apply-All-Targets
# Usage: apply-theme.sh <wallpaper_path>
# =============================================================================

WALLPAPER="$1"
WAL_DIR="$HOME/.cache/wal"
PRECOMPUTED="$WAL_DIR/precomputed"
WALL_KEY=$(basename "$WALLPAPER" | sed 's/\.[^.]*$//')
WALL_CACHE="$PRECOMPUTED/$WALL_KEY"
HYPR_COLORS="$HOME/.config/hypr/themes/current.conf"
HYPRLOCK_COLORS="$HOME/.config/hypr/themes/hyprlock-colors.conf"
WAYBAR_CSS="$WAL_DIR/colors-waybar.css"
GTK3_INI="$HOME/.config/gtk-3.0/settings.ini"
GTK4_INI="$HOME/.config/gtk-4.0/settings.ini"
GTK3_CSS="$HOME/.config/gtk-3.0/gtk.css"
GTK4_CSS="$HOME/.config/gtk-4.0/gtk.css"

# ── Pre-flight ────────────────────────────────────────────────────────────────
[[ ! -f "$WALLPAPER" ]] && { echo "Error: '$WALLPAPER' not found"; exit 1; }
mkdir -p "$PRECOMPUTED" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

# =============================================================================
# PHASE 1 — COLOR ANALYSIS (skip if cached)
# =============================================================================

if [[ -f "$WALL_CACHE/ui.env" && -d "$WALL_CACHE/wal" ]]; then
    echo "[theme] Cache hit — '$WALL_KEY'"
    # Restore ALL wal output files (terminal colors, kitty, css, json, etc.)
    find "$WALL_CACHE/wal" -maxdepth 1 -type f -exec cp {} "$WAL_DIR/" \;
    source "$WALL_CACHE/ui.env"

else
    echo "[theme] Analyzing '$WALL_KEY'..."

    # 1a. Brightness → light or dark mode
    brightness=$(magick "$WALLPAPER" -colorspace Gray -resize 1x1! -format "%[fx:u]" info:)
    is_light=$(python3 -c "print('yes' if $brightness > 0.58 else 'no')")
    if [[ "$is_light" == "yes" ]]; then
        WAL_MODE="-l"; GTK_SCHEME="prefer-light"; THEME_NAME="light"
    else
        WAL_MODE=""; GTK_SCHEME="prefer-dark"; THEME_NAME="dark"
    fi

    # 1b. Run pywal — generates colors + ALL terminal config files
    wal -i "$WALLPAPER" -n $WAL_MODE --saturate 0.8 -q

    # 1c. Extract UI palette — write to temp file, then source
    TMP_ENV=$(mktemp)
    python3 > "$TMP_ENV" << PYEOF
import colorsys

def hex_to_rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i+2], 16)/255.0 for i in (0, 2, 4)]

def rgb_to_hex(rgb):
    return '#%02x%02x%02x' % tuple(int(min(max(c,0),1)*255) for c in rgb)

with open('$WAL_DIR/colors') as f:
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
    source "$TMP_ENV"; rm -f "$TMP_ENV"

    # 1d. Waybar text contrast — sample 3 horizontal thirds of the wallpaper
    _contrast() {
        local x=$1 w=$2
        local hex lum
        hex=$(magick "$WALLPAPER" -crop "${w}x10%+${x}+0" -resize 1x1! txt: \
              | grep -o '#[0-9A-F]\{6\}' | head -1)
        lum=$(magick xc:"$hex" -colorspace Gray -format "%[fx:u]" info:)
        python3 -c "print('#000000' if $lum > 0.52 else '#ffffff')"
    }
    W=$(magick identify -format "%w" "$WALLPAPER")
    T=$((W / 3))
    L_TEXT=$(_contrast 0        $T)
    C_TEXT=$(_contrast $T       $T)
    R_TEXT=$(_contrast $((T*2)) $T)

    # 1e. Save to cache — copy ALL wal files so future hit is complete
    mkdir -p "$WALL_CACHE/wal"
    find "$WAL_DIR" -maxdepth 1 -type f -exec cp {} "$WALL_CACHE/wal/" \;
    cat > "$WALL_CACHE/ui.env" << ENVEOF
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
    echo "[theme] '$WALL_KEY' cached for instant future use."
fi

# Derive these from loaded/sourced vars (same logic for hit and miss)
ICON_THEME="Yaru-$ICON_VARIANT"
[[ "$GTK_SCHEME" == "prefer-dark" ]] && ICON_THEME="${ICON_THEME}-dark"
GTK_PREFER_DARK=$([[ "$GTK_SCHEME" == "prefer-dark" ]] && echo 1 || echo 0)
GTK_THEME_NAME=$([[ "$GTK_SCHEME" == "prefer-dark" ]] && echo "Adwaita-dark" || echo "Adwaita")

# =============================================================================
# PHASE 2 — APPLY TO ALL TARGETS (always runs, cache hit OR miss)
# =============================================================================

echo "[theme] Applying: ${THEME_NAME^} | accent $ACCENT"

# ── Target 1: Waybar CSS variables ───────────────────────────────────────────
cat > "$WAYBAR_CSS" << EOF
@define-color background $BG;
@define-color foreground $FG;
@define-color left_text $L_TEXT;
@define-color center_text $C_TEXT;
@define-color right_text $R_TEXT;
@define-color window_text $ACCENT_TEXT;
@define-color vibrant_accent $ACCENT;
@define-color bar_bg $BAR_BG;
EOF

# ── Target 2: GTK3 — theme name + settings.ini + accent CSS ──────────────────
# GTK3 ignores color-scheme; must use theme name + prefer-dark flag in ini
cat > "$GTK3_INI" << EOF
[Settings]
gtk-theme-name=$GTK_THEME_NAME
gtk-icon-theme-name=$ICON_THEME
gtk-application-prefer-dark-theme=$GTK_PREFER_DARK
gtk-font-name=Sans 10
EOF
cat > "$GTK3_CSS" << EOF
/* Auto-generated — do not edit */
@define-color theme_selected_bg_color $ACCENT;
@define-color theme_selected_fg_color $FG;
EOF

# ── Target 3: GTK4 / Libadwaita — accent only, Adwaita handles backgrounds ───
# Overriding bg/fg here causes unreadable UIs on extreme wallpaper palettes
cat > "$GTK4_INI" << EOF
[Settings]
gtk-theme-name=$GTK_THEME_NAME
gtk-icon-theme-name=$ICON_THEME
gtk-application-prefer-dark-theme=$GTK_PREFER_DARK
gtk-font-name=Sans 10
EOF
cat > "$GTK4_CSS" << EOF
/* Auto-generated — do not edit */
/* Accent only: Adwaita-dark/light manages backgrounds for readability */
@define-color accent_bg_color $ACCENT;
@define-color accent_color $ACCENT;
@define-color accent_fg_color #ffffff;
EOF

# ── Target 4: gsettings — tells GTK4/Libadwaita apps which mode to use ───────
gsettings set org.gnome.desktop.interface gtk-theme       "$GTK_THEME_NAME"
gsettings set org.gnome.desktop.interface color-scheme    "$GTK_SCHEME"
gsettings set org.gnome.desktop.interface icon-theme      "$ICON_THEME"

# ── Target 5: Hyprland borders ───────────────────────────────────────────────
cat > "$HYPR_COLORS" << EOF
general {
    col.active_border = rgba(${ACCENT#\#}ff) rgba(33333344) 45deg
    col.inactive_border = rgba(33333322)
}
EOF
hyprctl reload -q 2>/dev/null || true

# ── Target 6: Hyprlock ───────────────────────────────────────────────────────
FG_RAW=$(python3 -c "import json; d=json.load(open('$WAL_DIR/colors.json')); print(d['special']['foreground'])")
BG_RAW=$(python3 -c "import json; d=json.load(open('$WAL_DIR/colors.json')); print(d['special']['background'])")
cat > "$HYPRLOCK_COLORS" << EOF
# Auto-generated by apply-theme.sh — do not edit
\$foreground = $FG_RAW
\$background = $BG_RAW
\$accent     = $ACCENT
EOF

# ── Target 7: Kitty terminal (via remote control socket) ─────────────────────
# Patch kitty colors with our purified BG/FG.
# Pywal's raw color0 can be a weird minority color from gradient wallpapers;
# our $BG/$FG are properly clamped for readability.
KITTY_COLORS="$WAL_DIR/colors-kitty.conf"
if [[ -f "$KITTY_COLORS" ]]; then
    # Override background + foreground + cursor with purified values
    sed -i \
        -e "s/^background[[:space:]].*$/background   $BG/" \
        -e "s/^foreground[[:space:]].*$/foreground   $FG/" \
        -e "s/^cursor[[:space:]].*$/cursor       $FG/" \
        "$KITTY_COLORS"

    # Push via sockets (reliable, per-instance)
    for sock in /tmp/kitty-*; do
        [[ -S "$sock" ]] && kitty @ --to "unix:$sock" set-colors -a -c "$KITTY_COLORS" 2>/dev/null || true
    done
    # Fallback signal for any instance without a socket
    pkill -USR1 kitty 2>/dev/null || true
fi

# ── Target 8: Neovim ─────────────────────────────────────────────────────────
pkill -USR1 nvim 2>/dev/null || true

# ── Target 9: EWW widgets (if daemon is running) ─────────────────────────────
if pgrep -x eww > /dev/null; then
    python3 << PYEOF
import colorsys
def h2r(h):
    h=h.lstrip('#'); return [int(h[i:i+2],16)/255.0 for i in (0,2,4)]
br,bg2,bb = h2r("$BG"); fr,fg2,fb = h2r("$FG")
muted='#%02x%02x%02x'%(int((br+fr)/2*255),int((bg2+fg2)/2*255),int((bb+fb)/2*255))
open('$WAL_DIR/eww-colors.scss','w').write(
    "// Auto-generated\n"
    f"\$bg-glass:    rgba({int(br*255)},{int(bg2*255)},{int(bb*255)},0.80);\n"
    f"\$text-bright: $FG;\n"
    f"\$text-muted:  {muted};\n"
    f"\$accent:      $ACCENT;\n")
PYEOF
    eww kill && sleep 0.3 && eww daemon && sleep 0.3
    for win in clock-win sysinfo-win music-win volume-win; do
        eww open "$win" 2>/dev/null || true
    done
fi

# ── Target 10: Wallpaper display ─────────────────────────────────────────────
cp "$WALLPAPER" "$WAL_DIR/wal_wallpaper.jpg"
if ! pgrep -x awww-daemon > /dev/null; then awww-daemon & sleep 0.5; fi
awww img "$WALLPAPER" --transition-type center --transition-step 90 --transition-fps 60

# ── Target 11: Waybar restart (picks up new CSS vars) ────────────────────────
pkill waybar 2>/dev/null; sleep 0.2; waybar &

# ── Done ─────────────────────────────────────────────────────────────────────
wall_pretty=$(basename "$WALLPAPER" | sed 's/\.[^.]*$//' | sed 's/[_-]/ /g' \
    | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
notify-send "Adaptive Theme" "→ $wall_pretty\n● Mode: ${THEME_NAME^}  ● Accent: $ACCENT" \
    -i preferences-desktop-theme -t 3000
echo "[theme] Done — ${THEME_NAME^} | $ACCENT"
