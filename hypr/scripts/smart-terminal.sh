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

get_leaf_pid() {
    local pid=$1
    local children
    children=$(pgrep -P "$pid" 2>/dev/null)
    if [[ -z "$children" ]]; then
        echo "$pid"
    else
        for child in $children; do
            get_leaf_pid "$child"
        done
    fi
}

if is_terminal && [[ "$PID" =~ ^[0-9]+$ ]]; then
    LEAF=$(get_leaf_pid "$PID" | tail -1)
    CWD=$(readlink -f "/proc/$LEAF/cwd" 2>/dev/null)
    [[ -d "$CWD" ]] || CWD="$HOME"
    exec kitty --working-directory="$CWD"
else
    exec kitty
fi
