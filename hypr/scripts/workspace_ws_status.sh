#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Waybar workspace pill — shows workspaces of the current profile on THIS bar's monitor.
# WAYBAR_OUTPUT_NAME is set by waybar 0.15+ to this bar instance's monitor name.

STATE_DIR="$HOME/.local/share/hypr/ws_state"
THEME_CSS="$HOME/.config/waybar/theme.css"

monitor="${WAYBAR_OUTPUT_NAME:-${WAYBAR_OUTPUT:-}}"
[ -z "$monitor" ] && monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
mon_short=$(echo "$monitor" | tr -d '-')

profile=$(cat "$STATE_DIR/current_profile_${monitor}" 2>/dev/null || echo "1")

# Get the workspace that is active on THIS monitor (not the focused monitor)
our_ws=$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '
    .[] | select(.name == $mon) | .activeWorkspace | "\(.id)\t\(.name)"
')
active_id=$(printf '%s' "$our_ws" | cut -f1)
active_name=$(printf '%s' "$our_ws" | cut -f2)

clients=$(hyprctl clients -j 2>/dev/null)
monitor_id=$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .id')

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

L=$'' R=$''
active_span() { printf "<span size='large'><span foreground='%s'>%s</span><span background='%s' foreground='%s'>%s</span><span foreground='%s'>%s</span></span>" "$ACT_BG" "$L" "$ACT_BG" "$ACT_FG" "$1" "$ACT_BG" "$R"; }

text=""

if [ "$profile" = "1" ]; then
    # Workspace block for this monitor: derived from active workspace ID
    block_start=$(( (active_id - 1) / 10 * 10 + 1 ))
    block_end=$(( block_start + 9 ))

    mapfile -t occupied < <(jq -r --argjson mid "$monitor_id" '
        [.[] | select(.monitor == $mid and (.workspace.name | test("^[0-9]+$"))) | .workspace.id]
        | unique | sort[]
    ' <<< "$clients" 2>/dev/null)

    # Always include active workspace
    in_list=0
    for id in "${occupied[@]}"; do [ "$id" = "$active_id" ] && in_list=1; done
    [ "$in_list" = "0" ] && occupied+=("$active_id")
    IFS=$'\n' occupied=($(printf '%s\n' "${occupied[@]}" | sort -n)); unset IFS

    for ws_id in "${occupied[@]}"; do
        num=$(( ws_id - block_start + 1 ))
        [ -n "$text" ] && text="${text} "
        if [ "$ws_id" = "$active_id" ]; then
            text="${text}$(active_span "$num")"
        else
            text="${text}${num}"
        fi
    done
else
    # Profile N: p{N}w{M}{mon_short} workspaces
    mapfile -t occupied < <(jq -r --arg p "$profile" --arg ms "$mon_short" '
        [.[] | select(.workspace.name | test("^p" + $p + "w[0-9]+" + $ms + "$"))
        | .workspace.name] | unique | sort[]
    ' <<< "$clients" 2>/dev/null)

    # Always include active workspace if it belongs to this profile+monitor
    if [[ "$active_name" =~ ^p${profile}w[0-9]+${mon_short}$ ]]; then
        in_list=0
        for ws in "${occupied[@]}"; do [ "$ws" = "$active_name" ] && in_list=1; done
        [ "$in_list" = "0" ] && occupied+=("$active_name")
        IFS=$'\n' occupied=($(printf '%s\n' "${occupied[@]}" | sort -V)); unset IFS
    fi

    for ws_name in "${occupied[@]}"; do
        num=$(echo "$ws_name" | sed "s/^p[0-9]*w\([0-9]*\)${mon_short}\$/\1/")
        [ -n "$text" ] && text="${text} "
        if [ "$ws_name" = "$active_name" ]; then
            text="${text}$(active_span "$num")"
        else
            text="${text}${num}"
        fi
    done
fi

[ -z "$text" ] && text="$(active_span 1)"

printf '{"text":"%s","tooltip":"Profile %s @ %s"}\n' "$text" "$profile" "$monitor"
