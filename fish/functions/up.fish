function up --wraps='hyde-shell pm upgrade' --wraps='yay --noconfirm' --description 'alias up=yay --noconfirm'
    yay --noconfirm $argv
end
