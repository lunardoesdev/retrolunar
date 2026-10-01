return recipe({
    version = "0.7.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/ltrace.tar.bz2 ]; then
          curl -fSL -C - -o dl/ltrace.tar.bz2 "https://gitlab.com/ltrace/ltrace/-/archive/v0.7.3/ltrace-v0.7.3.tar.bz2" || curl -fSL -C - -o dl/ltrace.tar.bz2 "https://deb.debian.org/debian/pool/main/l/ltrace/ltrace_0.7.3.orig.tar.bz2"
        fi
        rm -rf src
        mkdir -p src
        tar -xjf dl/ltrace.tar.bz2 -C src --strip-components=1
        mkdir -p $OUT/ltrace
        cp -r src/* $OUT/ltrace/
    ]]
})