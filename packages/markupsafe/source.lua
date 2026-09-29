return recipe({
    version = "3.0.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/markupsafe.tar.gz ]; then
          curl -fSL -C - -o dl/markupsafe.tar.gz "https://pypi.org/packages/source/m/markupsafe/markupsafe-3.0.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/markupsafe.tar.gz -C src --strip-components=1
        mkdir -p $OUT/markupsafe
        cp -r src/* $OUT/markupsafe/
    ]]
})
