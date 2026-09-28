return recipe({
    version = "1.26",
    build = [[
        mkdir -p dl
        if [ ! -f dl/gdbm.tar.gz ]; then
          curl -fSL -C - -o dl/gdbm.tar.gz "https://ftp.gnu.org/gnu/gdbm/gdbm-1.26.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/gdbm.tar.gz -C src --strip-components=1
        mkdir -p $OUT/gdbm
        cp -r src/* $OUT/gdbm/
    ]]
})
