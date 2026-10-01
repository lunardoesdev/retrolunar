return recipe({
    version = "6.2.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/CGAL.tar.xz ]; then
          curl -fSL -C - -o dl/CGAL.tar.xz "https://github.com/CGAL/cgal/releases/download/v6.2.1/CGAL-6.2.1.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        # The release publishes .tar.xz and .zip; there is no .tar.gz asset
        # (that URL 404s), so this is the one to fetch. Top directory is
        # CGAL-6.2.1, hence --strip-components=1.
        tar -xJf dl/CGAL.tar.xz -C src --strip-components=1
        mkdir -p $OUT/CGAL
        cp -r src/* $OUT/CGAL/
    ]]
})
