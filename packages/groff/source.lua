return recipe({
    version = "1.24.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/groff.tar.gz ]; then
          curl -fSL -C - -o dl/groff.tar.gz "https://ftp.gnu.org/gnu/groff/groff-1.24.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/groff.tar.gz -C src --strip-components=1
        mkdir -p $OUT/groff
        cp -r src/* $OUT/groff/
    ]]
})
