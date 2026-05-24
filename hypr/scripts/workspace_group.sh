#!/bin/bash
# Profile system — per-monitor, dynamic numbered profiles.
# Profile 1: native workspaces 1-30 (split-monitor-workspaces, per-monitor blocks of 10)
# Profile N (N≥2): named workspaces p{N}w{M}{mon_short} (e.g. p2w1DP2)

STATE_DIR="$HOME/.local/share/hypr/ws_state"
mkdir -p "$STATE_DIR"

get_active_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

# Sanitize monitor name for use in workspace names (remove dashes)
mon_short() { echo "$1" | tr -d '-'; }

profile_file() { echo "$STATE_DIR/current_profile_${1}"; }

get_profile() {
    local mon; mon=$(get_active_monitor)
    cat "$(profile_file "$mon")" 2>/dev/null || echo "1"
}

# Hyprctl workspace arg for profile P, workspace N, monitor MON
ws_arg() {
    local p=$1 n=$2 mon=$3
    [ "$p" = "1" ] && echo "$n" || echo "name:p${p}w${n}$(mon_short "$mon")"
}

dispatch_ws() {
    local ws=$1 mon=$2
    # Place new named workspaces on the correct monitor
    [[ "$ws" == name:* ]] && hyprctl dispatch moveworkspacetomonitor "$ws" "$mon" 2>/dev/null
    hyprctl dispatch workspace "$ws"
}

save_profile_state() {
    local p=$1 mon=$2
    local ws
    ws=$(hyprctl activeworkspace -j | jq -r '
        if (.name | test("^[0-9]+$") | not) and .name != ""
        then .name
        else (.id | tostring)
        end
    ')
    echo "$ws" > "$STATE_DIR/profile_${p}_${mon}"
}

restore_profile_state() {
    local p=$1 mon=$2
    local ms; ms=$(mon_short "$mon")
    local saved
    saved=$(cat "$STATE_DIR/profile_${p}_${mon}" 2>/dev/null)

    if [ -z "$saved" ]; then
        dispatch_ws "$(ws_arg "$p" 1 "$mon")" "$mon"
        return
    fi

    if [ "$p" = "1" ]; then
        [[ "$saved" =~ ^[0-9]+$ ]] \
            && hyprctl dispatch workspace "$saved" \
            || hyprctl dispatch workspace "name:$saved"
    else
        [[ "$saved" =~ ^p[0-9]+w[0-9]+${ms}$ ]] \
            && dispatch_ws "name:$saved" "$mon" \
            || dispatch_ws "$(ws_arg "$p" 1 "$mon")" "$mon"
    fi
}

notify_waybar() {
    pkill -SIGRTMIN+8 waybar 2>/dev/null  # profile pill
    pkill -SIGRTMIN+9 waybar 2>/dev/null  # workspace pill
}

switch_to_profile() {
    local new=$1
    local mon; mon=$(get_active_monitor)
    local cur; cur=$(cat "$(profile_file "$mon")" 2>/dev/null || echo "1")
    [ "$new" = "$cur" ] && return
    save_profile_state "$cur" "$mon"
    echo "$new" > "$(profile_file "$mon")"
    restore_profile_state "$new" "$mon"
    notify-send "Perfil" "$new" -t 1000 2>/dev/null
    notify_waybar
}

get_current_ws_num() {
    local p=$1
    if [ "$p" = "1" ]; then
        local id; id=$(hyprctl activeworkspace -j | jq -r '.id')
        echo $(( (id - 1) % 10 + 1 ))
    else
        local name; name=$(hyprctl activeworkspace -j | jq -r '.name')
        [[ "$name" =~ ^p[0-9]+w([0-9]+) ]] && echo "${BASH_REMATCH[1]}" || echo "1"
    fi
}

case $1 in
    profile-next)
        p=$(get_profile); switch_to_profile $(( p + 1 )) ;;
    profile-prev)
        p=$(get_profile); new=$(( p - 1 )); [ "$new" -lt 1 ] && new=1; switch_to_profile "$new" ;;
    profile-go)
        switch_to_profile "$2" ;;

    switch)
        mon=$(get_active_monitor)
        p=$(cat "$(profile_file "$mon")" 2>/dev/null || echo "1")
        if [ "$p" = "1" ]; then
            hyprctl dispatch split-workspace "$2"
        else
            dispatch_ws "$(ws_arg "$p" "$2" "$mon")" "$mon"
        fi
        pkill -SIGRTMIN+9 waybar 2>/dev/null
        ;;
    switch-next)
        mon=$(get_active_monitor)
        p=$(cat "$(profile_file "$mon")" 2>/dev/null || echo "1")
        if [ "$p" = "1" ]; then
            hyprctl dispatch split-cycleworkspaces next
        else
            n=$(get_current_ws_num "$p")
            dispatch_ws "$(ws_arg "$p" $(( n + 1 )) "$mon")" "$mon"
        fi
        pkill -SIGRTMIN+9 waybar 2>/dev/null
        ;;
    switch-prev)
        mon=$(get_active_monitor)
        p=$(cat "$(profile_file "$mon")" 2>/dev/null || echo "1")
        if [ "$p" = "1" ]; then
            hyprctl dispatch split-cycleworkspaces prev
        else
            n=$(get_current_ws_num "$p")
            new=$(( n - 1 )); [ "$new" -lt 1 ] && new=1
            dispatch_ws "$(ws_arg "$p" "$new" "$mon")" "$mon"
        fi
        pkill -SIGRTMIN+9 waybar 2>/dev/null
        ;;

    move)
        mon=$(get_active_monitor)
        p=$(cat "$(profile_file "$mon")" 2>/dev/null || echo "1")
        if [ "$p" = "1" ]; then
            hyprctl dispatch split-movetoworkspace "$2"
        else
            hyprctl dispatch movetoworkspace "$(ws_arg "$p" "$2" "$mon")"
        fi
        ;;
    move-silent)
        mon=$(get_active_monitor)
        p=$(cat "$(profile_file "$mon")" 2>/dev/null || echo "1")
        if [ "$p" = "1" ]; then
            hyprctl dispatch split-movetoworkspacesilent "$2"
        else
            hyprctl dispatch movetoworkspacesilent "$(ws_arg "$p" "$2" "$mon")"
        fi
        ;;
esac
