function upboot --wraps='up && reboot' --description 'alias upboot=up && reboot'
    up && reboot $argv
end
