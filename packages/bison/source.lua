return recipe({
    version = "3.8.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/bison.tar.xz ]; then
          curl -fSL -C - -o dl/bison.tar.xz "https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/bison.tar.xz -C src --strip-components=1
        mkdir -p $OUT/bison
        cp -r src/* $OUT/bison/
    ]]
})
