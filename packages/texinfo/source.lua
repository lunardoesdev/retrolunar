return recipe({
    version = "7.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/texinfo.tar.xz ]; then
          curl -fSL -C - -o dl/texinfo.tar.xz "https://ftp.gnu.org/gnu/texinfo/texinfo-7.3.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/texinfo.tar.xz -C src --strip-components=1
        mkdir -p $OUT/texinfo
        cp -r src/* $OUT/texinfo/
    ]]
})
