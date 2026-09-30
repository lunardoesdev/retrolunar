return recipe({
    version = "2.1.12",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libevent.tar.gz ]; then
          curl -fSL -C - -o dl/libevent.tar.gz "https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libevent.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libevent
        cp -r src/* $OUT/libevent/
    ]]
})
