return recipe({
    version = "2.32.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/isa-l.tar.gz ]; then
          curl -fSL -C - -o dl/isa-l.tar.gz "https://github.com/intel/isa-l/archive/refs/tags/v2.32.1.tar.gz" || \
          curl -fSL -C - -o dl/isa-l.tar.gz "https://github.com/intel/isa-l/archive/refs/tags/v2.32.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        # GitHub source archives have no configure/aclocal.m4/Makefile.in at
        # all (checked against the 536-entry tarball index), so there is no
        # generated build system to reuse; only the upstream sources and the
        # hand-written Makefile.unx come out of this.
        tar -xzf dl/isa-l.tar.gz -C src --strip-components=1
        mkdir -p $OUT/isa-l
        cp -r src/* $OUT/isa-l/
    ]]
})
