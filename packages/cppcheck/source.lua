return recipe({
    version = "2.22.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/cppcheck.tar.gz ]; then
          curl -fSL -C - -o dl/cppcheck.tar.gz "https://github.com/cppcheck-opensource/cppcheck/archive/refs/tags/2.22.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/cppcheck.tar.gz -C src --strip-components=1
        mkdir -p $OUT/cppcheck
        cp -r src/* $OUT/cppcheck/
    ]]
})