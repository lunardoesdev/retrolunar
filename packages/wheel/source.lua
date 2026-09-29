return recipe({
    version = "0.48.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/wheel.tar.gz ]; then
          curl -fSL -C - -o dl/wheel.tar.gz "https://pypi.org/packages/source/w/wheel/wheel-0.48.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/wheel.tar.gz -C src --strip-components=1
        mkdir -p $OUT/wheel
        cp -r src/* $OUT/wheel/
    ]]
})
