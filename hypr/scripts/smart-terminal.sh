#!/bin/bash
# Opens kitty in the same directory as the focused terminal, or $HOME otherwise.

TERM_CLASSES=("kitty")

ACTIVE=$(hyprctl activewindow -j)
CLASS=$(echo "$ACTIVE" | jq -r '.class')
PID=$(echo "$ACTIVE" | jq -r '.pid')

is_terminal() {
    for t in "${TERM_CLASSES[@]}"; do
        [[ "${CLASS,,}" == *"${t,,}"* ]] && return 0
    done
    return 1
}

get_shell_pid() {
    local pid=$1
    local children child comm
    children=$(pgrep -P "$pid" 2>/dev/null)
    for child in $children; do
        comm=$(cat "/proc/$child/comm" 2>/dev/null)
        case "$comm" in
            bash|fish|zsh|sh|dash|ksh|csh|tcsh) echo "$child"; return ;;
        esac
    done
    # fallback: first child
    echo "$children" | head -1
}

if is_terminal && [[ "$PID" =~ ^[0-9]+$ ]]; then
    SHELL_PID=$(get_shell_pid "$PID")
    CWD=$(readlink -f "/proc/$SHELL_PID/cwd" 2>/dev/null)
    [[ -d "$CWD" ]] || CWD="$HOME"
    exec kitty --working-directory="$CWD"
else
    exec kitty
fi
