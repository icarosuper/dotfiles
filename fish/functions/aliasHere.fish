function aliasHere
    if test (count $argv) -eq 0
        echo "Uso: aliasHere <nome>"
        return 1
    end

    set nome $argv[1]
    set pasta (pwd)

    alias --save $nome="cd $pasta"
    echo "Alias '$nome' criado para '$pasta'"
end
