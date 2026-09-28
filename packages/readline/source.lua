return recipe({
    version = "8.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/readline.tar.gz ]; then
          curl -fSL -C - -o dl/readline.tar.gz "https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/readline.tar.gz -C src --strip-components=1
        mkdir -p $OUT/readline
        cp -r src/* $OUT/readline/
    ]]
})
