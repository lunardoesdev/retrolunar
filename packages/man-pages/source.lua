return recipe({
    version = "6.15",
    build = [[
        mkdir -p dl
        if [ ! -f dl/man-pages.tar.xz ]; then
          curl -fSL -C - -o dl/man-pages.tar.xz "https://mirrors.edge.kernel.org/pub/linux/docs/man-pages/man-pages-6.15.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/man-pages.tar.xz -C src --strip-components=1
        mkdir -p $OUT/man-pages
        cp -r src/* $OUT/man-pages/
    ]]
})
