return recipe({
    version = "3.12.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/flit_core.tar.gz ]; then
          curl -fSL -C - -o dl/flit_core.tar.gz "https://pypi.org/packages/source/f/flit-core/flit_core-3.12.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/flit_core.tar.gz -C src --strip-components=1
        mkdir -p $OUT/flit-core
        cp -r src/* $OUT/flit-core/
    ]]
})
