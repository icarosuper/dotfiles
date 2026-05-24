#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Waybar profile pill — shows profiles with open windows on THIS bar's monitor.
# WAYBAR_OUTPUT_NAME is set by waybar 0.15+ to this bar instance's monitor name.

STATE_DIR="$HOME/.local/share/hypr/ws_state"
THEME_CSS="$HOME/.config/waybar/theme.css"

monitor="${WAYBAR_OUTPUT_NAME:-${WAYBAR_OUTPUT:-}}"
[ -z "$monitor" ] && monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
mon_short=$(echo "$monitor" | tr -d '-')
monitor_id=$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .id')

current=$(cat "$STATE_DIR/current_profile_${monitor}" 2>/dev/null || echo "1")

# Extract active span colors from theme.css (pure RGB of wb-act-bg/fg, matching native CSS look)
_theme_colors=$(awk '
    /wb-act-fg/ && /rgba/ { match($0, /rgba\(([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)/, a); fg=sprintf("#%02x%02x%02x", a[1]+0, a[2]+0, a[3]+0) }
    /wb-act-bg/ && /rgba/ { match($0, /rgba\(([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)/, a); bg=sprintf("#%02x%02x%02x", a[1]+0, a[2]+0, a[3]+0) }
    END { print fg " " bg }
' "$THEME_CSS" 2>/dev/null)
ACT_FG=$(printf '%s' "$_theme_colors" | cut -d' ' -f1)
ACT_BG=$(printf '%s' "$_theme_colors" | cut -d' ' -f2)
[ -z "$ACT_FG" ] && ACT_FG="#ffccd8"
[ -z "$ACT_BG" ] && ACT_BG="#d1768b"

L=$'\xee\x82\xb6' R=$'\xee\x82\xb4'

declare -A shown
shown["$current"]=1

clients=$(hyprctl clients -j 2>/dev/null)

# Profile 1: windows on native workspaces on THIS monitor
p1=$(jq -r --argjson mid "$monitor_id" '
    [.[] | select(.monitor == $mid and (.workspace.name | test("^[0-9]+$")))] | length
' <<< "$clients" 2>/dev/null || echo 0)
[ "${p1:-0}" -gt 0 ] && shown[1]=1

# Profiles 2+: windows on p{N}w{M}{mon_short} workspaces
while IFS= read -r ws_name; do
    if [[ "$ws_name" =~ ^p([0-9]+)w[0-9]+${mon_short}$ ]]; then
        shown["${BASH_REMATCH[1]}"]=1
    fi
done < <(jq -r '.[].workspace.name' <<< "$clients" 2>/dev/null \
    | grep -E "^p[0-9]+w[0-9]+${mon_short}$")

IFS=$'\n' sorted=($(printf '%s\n' "${!shown[@]}" | sort -n)); unset IFS

text=""
for p in "${sorted[@]}"; do
    [ -n "$text" ] && text="${text} "
    if [ "$p" = "$current" ]; then
        text="${text}<span size='large'><span foreground='${ACT_BG}'>${L}</span><span background='${ACT_BG}' foreground='${ACT_FG}'>${p}</span><span foreground='${ACT_BG}'>${R}</span></span>"
    else
        text="${text}${p}"
    fi
done

[ -z "$text" ] && text="<span size='large'><span foreground='${ACT_BG}'>${L}</span><span background='${ACT_BG}' foreground='${ACT_FG}'>1</span><span foreground='${ACT_BG}'>${R}</span></span>"

printf '{"text":"%s","tooltip":"Profile %s @ %s"}\n' "$text" "$current" "$monitor"
