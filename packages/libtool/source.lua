return recipe({
    version = "2.5.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libtool.tar.xz ]; then
          curl -fSL -C - -o dl/libtool.tar.xz "https://ftp.gnu.org/gnu/libtool/libtool-2.5.4.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/libtool.tar.xz -C src --strip-components=1
        mkdir -p $OUT/libtool
        cp -r src/* $OUT/libtool/
    ]]
})
