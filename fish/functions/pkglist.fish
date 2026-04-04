function pkglist --wraps='pacman -Qq | fzf --preview "pacman -Qil {}" --layout=reverse' --description 'alias pkglist pacman -Qq | fzf --preview "pacman -Qil {}" --layout=reverse'
    pacman -Qq | fzf --preview "pacman -Qil {}" --layout=reverse $argv
end
