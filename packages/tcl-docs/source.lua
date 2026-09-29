return recipe({
    version = "8.6.18",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tcl-docs.tar.gz ]; then
          curl -fSL -C - -o dl/tcl-docs.tar.gz "https://sourceforge.net/projects/tcl/files/Tcl/8.6.18/tcl8.6.18-html.tar.gz/download"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/tcl-docs.tar.gz -C src --strip-components=1
        mkdir -p $OUT/tcl-docs
        cp -r src/* $OUT/tcl-docs/
    ]]
})
