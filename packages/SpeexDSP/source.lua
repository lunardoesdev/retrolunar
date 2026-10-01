-- Xiph no longer hosts a standalone SpeexDSP dist tarball (every
-- downloads.xiph.org/releases/speexdsp/speexdsp-1.2.*.tar.gz is a 404), and
-- the GitHub tag archive ships no generated configure. Debian's pool carries
-- the UNMODIFIED upstream orig tarball, which does ship configure,
-- aclocal.m4 and config.h.in - the same situation and the same remedy as
-- intltool, whose recipe fetches from Debian's pool for exactly this reason.
return recipe({
    version = "1.2.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/speexdsp.tar.gz ]; then
          curl -fSL -C - -o dl/speexdsp.tar.gz "https://deb.debian.org/debian/pool/main/s/speexdsp/speexdsp_1.2.1.orig.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/speexdsp.tar.gz -C src --strip-components=1
        mkdir -p $OUT/SpeexDSP
        cp -r src/* $OUT/SpeexDSP/
    ]]
})
