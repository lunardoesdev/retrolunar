return recipe({
    version = "4.10.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/findutils.tar.xz ]; then
          curl -fSL -C - -o dl/findutils.tar.xz "https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/findutils.tar.xz -C src --strip-components=1
        mkdir -p $OUT/findutils
        cp -r src/* $OUT/findutils/
    ]]
})
