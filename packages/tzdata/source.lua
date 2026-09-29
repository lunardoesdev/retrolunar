return recipe({
    version = "2025b",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tzdata.tar.gz ]; then
          curl -fSL -C - -o dl/tzdata.tar.gz "https://data.iana.org/time-zones/releases/tzdata2025b.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        # The IANA release tarball has no top-level directory.
        tar -xzf dl/tzdata.tar.gz -C src
        mkdir -p $OUT/tzdata
        cp -r src/* $OUT/tzdata/
    ]]
})
