return recipe({
    version = "0.193",
    build = [[
        mkdir -p dl
        if [ ! -f dl/elfutils.tar.bz2 ]; then
          curl -fSL -C - -o dl/elfutils.tar.bz2 "https://sourceware.org/elfutils/ftp/0.193/elfutils-0.193.tar.bz2"
        fi
        rm -rf src
        mkdir -p src
        tar -xjf dl/elfutils.tar.bz2 -C src --strip-components=1
        mkdir -p $OUT/elfutils
        cp -r src/* $OUT/elfutils/
    ]]
})
