-- soundtouch's official dist tarballs (surina.net) ship configure.ac and
-- Makefile.am but NO generated configure - checked 2.3.2, 2.3.3, 2.4.0 and
-- 2.4.1, all zero. Debian's pool copies are "+ds" repacks rather than
-- unmodified upstream, so this recipe uses the official tarball and the
-- project's own CMake build, which is first-class and needs no bootstrap.
-- Note the tarball's top directory is plain "soundtouch/", not versioned.
return recipe({
    version = "2.4.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/soundtouch.tar.gz ]; then
          curl -fSL -C - -o dl/soundtouch.tar.gz "https://www.surina.net/soundtouch/soundtouch-2.4.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/soundtouch.tar.gz -C src --strip-components=1
        mkdir -p $OUT/soundtouch
        cp -r src/* $OUT/soundtouch/
    ]]
})
