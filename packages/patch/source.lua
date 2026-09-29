return recipe({
    version = "2.8",
    build = [[
        mkdir -p dl
        if [ ! -f dl/patch.tar.xz ]; then
          curl -fSL -C - -o dl/patch.tar.xz "https://ftp.gnu.org/gnu/patch/patch-2.8.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/patch.tar.xz -C src --strip-components=1
        mkdir -p $OUT/patch
        cp -r src/* $OUT/patch/
    ]]
})
