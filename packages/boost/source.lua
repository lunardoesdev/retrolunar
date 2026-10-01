return recipe({
    version = "1.92.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/boost_1_92_0.tar.gz ]; then
          curl -fSL -C - -o dl/boost_1_92_0.tar.gz "https://archives.boost.io/release/1.92.0/source/boost_1_92_0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/boost_1_92_0.tar.gz -C src --strip-components=1
        mkdir -p $OUT/boost
        cp -r src/* $OUT/boost/
    ]]
})