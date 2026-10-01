return recipe({
    version = "4.14.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/ccache.tar.xz ]; then
          curl -fSL -C - -o dl/ccache.tar.xz "https://github.com/ccache/ccache/releases/download/v4.14.1/ccache-4.14.1.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/ccache.tar.xz -C src --strip-components=1
        mkdir -p $OUT/ccache
        cp -r src/* $OUT/ccache/
    ]]
})
