return recipe({
    version = "7.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/strace.tar.xz ]; then
          curl -fSL -C - -o dl/strace.tar.xz "https://github.com/strace/strace/releases/download/v7.2/strace-7.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/strace.tar.xz -C src --strip-components=1
        mkdir -p $OUT/strace
        cp -r src/* $OUT/strace/
    ]]
})