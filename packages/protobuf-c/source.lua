return recipe({
    version = "1.5.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/protobuf-c.tar.gz ]; then
          curl -fSL -C - -o dl/protobuf-c.tar.gz "https://github.com/protobuf-c/protobuf-c/releases/download/v1.5.1/protobuf-c-1.5.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        # The release tarball, not the git tag: it is an automake dist
        # archive and already carries a generated configure (706594 bytes),
        # Makefile.in, config.h.in and aclocal.m4, plus the m4/ macros the
        # configure script inlines. The git tag has none of those.
        tar -xzf dl/protobuf-c.tar.gz -C src --strip-components=1
        mkdir -p $OUT/protobuf-c
        cp -r src/* $OUT/protobuf-c/
    ]]
})
