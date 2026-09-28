return recipe({
    version = "3.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/gperf.tar.gz ]; then
          curl -fSL -C - -o dl/gperf.tar.gz "https://ftp.gnu.org/gnu/gperf/gperf-3.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/gperf.tar.gz -C src --strip-components=1
        mkdir -p $OUT/gperf
        cp -r src/* $OUT/gperf/
    ]]
})
