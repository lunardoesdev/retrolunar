return recipe({
    version = "2.4.11",
    build = [[
        mkdir -p dl
        if [ ! -f dl/doctest.tar.gz ]; then
          curl -fSL -C - -o dl/doctest.tar.gz "https://github.com/doctest/doctest/archive/refs/tags/v2.4.11.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/doctest.tar.gz -C src --strip-components=1
        mkdir -p $OUT/doctest
        cp -r src/* $OUT/doctest/
    ]]
})
