return recipe({
    version = "8.6.16",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tcl.tar.gz ]; then
          curl -fSL -C - -o dl/tcl.tar.gz "https://downloads.sourceforge.net/tcl/tcl8.6.16-src.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/tcl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/tcl
        cp -r src/* $OUT/tcl/
    ]]
})
