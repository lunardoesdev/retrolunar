return recipe({
    version = "2.42.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/util-linux.tar.xz ]; then
          curl -fSL -C - -o dl/util-linux.tar.xz "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.42/util-linux-2.42.4.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/util-linux.tar.xz -C src --strip-components=1
        mkdir -p $OUT/util-linux
        cp -r src/* $OUT/util-linux/
    ]]
})
