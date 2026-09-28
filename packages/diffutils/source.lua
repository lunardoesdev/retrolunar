return recipe({
    version = "3.12",
    build = [[
        mkdir -p dl
        if [ ! -f dl/diffutils.tar.xz ]; then
          curl -fSL -C - -o dl/diffutils.tar.xz "https://ftp.gnu.org/gnu/diffutils/diffutils-3.12.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/diffutils.tar.xz -C src --strip-components=1
        mkdir -p $OUT/diffutils
        cp -r src/* $OUT/diffutils/
    ]]
})
