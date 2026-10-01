return recipe({
    version = "1.5.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/heaptrack.tar.bz2 ]; then
          curl -fSL -C - -o dl/heaptrack.tar.bz2 "https://invent.kde.org/utilities/heaptrack/-/archive/v1.5.0/heaptrack-v1.5.0.tar.bz2"
        fi
        rm -rf src
        mkdir -p src
        tar -xjf dl/heaptrack.tar.bz2 -C src --strip-components=1
        mkdir -p $OUT/heaptrack
        cp -r src/* $OUT/heaptrack/
    ]]
})