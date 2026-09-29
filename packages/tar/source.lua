return recipe({
    version = "1.35",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tar.tar.xz ]; then
          curl -fSL -C - -o dl/tar.tar.xz "https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/tar.tar.xz -C src --strip-components=1
        mkdir -p $OUT/tar
        cp -r src/* $OUT/tar/
    ]]
})
