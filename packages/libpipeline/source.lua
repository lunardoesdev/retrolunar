return recipe({
    version = "1.5.8",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libpipeline.tar.gz ]; then
          curl -fSL -C - -o dl/libpipeline.tar.gz "https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.8.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libpipeline.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libpipeline
        cp -r src/* $OUT/libpipeline/
    ]]
})
