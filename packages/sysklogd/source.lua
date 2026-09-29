return recipe({
    version = "2.7.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/sysklogd.tar.gz ]; then
          curl -fSL -C - -o dl/sysklogd.tar.gz "https://github.com/troglobit/sysklogd/releases/download/v2.7.2/sysklogd-2.7.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/sysklogd.tar.gz -C src --strip-components=1
        mkdir -p $OUT/sysklogd
        cp -r src/* $OUT/sysklogd/
    ]]
})
