return recipe({
    version = "262",
    build = [[
        mkdir -p dl
        if [ ! -f dl/systemd-man-pages.tar.xz ]; then
          curl -fSL -C - -o dl/systemd-man-pages.tar.xz "https://anduin.linuxfromscratch.org/LFS/systemd-man-pages-262.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/systemd-man-pages.tar.xz -C src --strip-components=1
        mkdir -p $OUT/systemd-man-pages
        cp -r src/* $OUT/systemd-man-pages/
    ]]
})
