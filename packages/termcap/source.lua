return recipe({
    version = "1.3.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/termcap.tar.gz ]; then
          curl -fSL -C - -o dl/termcap.tar.gz "https://ftp.gnu.org/gnu/termcap/termcap-1.3.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/termcap.tar.gz -C src --strip-components=1
        mkdir -p $OUT/termcap
        cp -r src/* $OUT/termcap/
    ]]
})
