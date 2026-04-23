#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

msg() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# 1. Dependências
msg "Instalando pacotes (requer sudo)"
sudo pacman -S --needed --noconfirm \
    hyprland waybar \
    meson ninja cmake pkgconf git

# 2. Corrigir dono de /var/cache/hyprpm (hyprpm grava lá)
if [[ -d /var/cache/hyprpm && "$(stat -c %U /var/cache/hyprpm)" != "$USER" ]]; then
    msg "Ajustando dono de /var/cache/hyprpm para $USER"
    sudo chown -R "$USER:$USER" /var/cache/hyprpm
fi

# 3. Plugin split-monitor-workspaces
PLUGIN_URL="https://github.com/zjeffer/split-monitor-workspaces"
PLUGIN_NAME="split-monitor-workspaces"

if ! hyprpm list 2>/dev/null | grep -q "$PLUGIN_NAME"; then
    msg "Adicionando plugin $PLUGIN_NAME"
    hyprpm update -v || true
    hyprpm add "$PLUGIN_URL"
fi

msg "Habilitando plugin"
hyprpm enable "$PLUGIN_NAME" || true

# Fallback: hyprpm às vezes falha ao copiar .so entre filesystems
PLUGIN_DIR="/var/cache/hyprpm/$USER/$PLUGIN_NAME"
SO="$PLUGIN_DIR/$PLUGIN_NAME.so"
BUILD_SO="/run/user/$(id -u)/hyprpm/$USER/build/lib${PLUGIN_NAME}.so"
if [[ ! -f "$SO" && -f "$BUILD_SO" ]]; then
    warn "hyprpm não instalou o .so; copiando manualmente"
    cp "$BUILD_SO" "$SO"
fi

# 4. Symlinks (arquivo a arquivo, preserva configs não versionadas)
link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "$dst.bak.$(date +%s)"
        warn "backup: $dst.bak.*"
    fi
    ln -sfn "$src" "$dst"
    msg "link: $dst -> $src"
}

# hypr
for f in hyprland.conf hyprsunset.conf keybindings.conf windowrules.conf workspaces.conf; do
    [[ -f "$REPO/hypr/$f" ]] && link "$REPO/hypr/$f" "$CONFIG/hypr/$f"
done
[[ -d "$REPO/hypr/scripts" ]] && link "$REPO/hypr/scripts" "$CONFIG/hypr/scripts"

# waybar
[[ -f "$REPO/waybar/config.jsonc" ]] && link "$REPO/waybar/config.jsonc" "$CONFIG/waybar/config.jsonc"
[[ -d "$REPO/waybar/layouts" ]] && link "$REPO/waybar/layouts" "$CONFIG/waybar/layouts"

# fish
[[ -d "$REPO/fish/functions" ]] && link "$REPO/fish/functions" "$CONFIG/fish/functions"

msg "Feito. Reinicie Hyprland (ou rode: hyprpm reload -n) e waybar."
