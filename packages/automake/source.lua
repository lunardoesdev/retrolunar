return recipe({
    version = "1.18.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/automake.tar.xz ]; then
          curl -fSL -C - -o dl/automake.tar.xz "https://ftp.gnu.org/gnu/automake/automake-1.18.1.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/automake.tar.xz -C src --strip-components=1
        mkdir -p $OUT/automake
        cp -r src/* $OUT/automake/
    ]]
})
