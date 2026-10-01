return recipe({
    version = "7.14.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/SuiteSparse.tar.gz ]; then
          curl -fSL -C - -o dl/SuiteSparse.tar.gz "https://github.com/DrTimothyAldenDavis/SuiteSparse/archive/refs/tags/v7.14.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        # The project moved from the scipy org to DrTimothyAldenDavis; the
        # scipy/suitesparse archive URLs now 404, and so does the releases
        # atom feed. The tarball's top directory is SuiteSparse-7.14.1, hence
        # --strip-components=1.
        tar -xzf dl/SuiteSparse.tar.gz -C src --strip-components=1
        mkdir -p $OUT/SuiteSparse
        cp -r src/* $OUT/SuiteSparse/
    ]]
})
