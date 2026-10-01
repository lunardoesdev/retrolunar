return recipe({
    version = "2.13.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/hwloc-2.13.0.tar.gz ]; then
          curl -fSL -C - -o dl/hwloc-2.13.0.tar.gz "https://download.open-mpi.org/release/hwloc/v2.13/hwloc-2.13.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/hwloc-2.13.0.tar.gz -C src --strip-components=1
        mkdir -p $OUT/hwloc
        cp -r src/* $OUT/hwloc/
    ]]
})