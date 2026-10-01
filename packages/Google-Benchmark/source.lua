return recipe({
    version = "1.9.5",
    build = [[
        mkdir -p dl
        if [ ! -f dl/benchmark.tar.gz ]; then
          curl -fSL -C - -o dl/benchmark.tar.gz "https://github.com/google/benchmark/archive/refs/tags/v1.9.5.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/benchmark.tar.gz -C src --strip-components=1
        mkdir -p $OUT/Google-Benchmark
        cp -r src/* $OUT/Google-Benchmark/
    ]]
})