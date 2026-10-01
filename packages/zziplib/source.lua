-- zziplib: a ZIP access library built on zlib, by Guido Draheim.
--
-- Version: 0.13.78. Upstream's canonical tarball is
-- sourceforge.net/projects/zzip/files/zzip/0.13.78/zzip-0.13.78.tar.gz, but
-- SourceForge's CDN answers HTTP 522 to this network on every mirror tried
-- (downloads., master.dl, phoenixnap.dl, cfhcable.dl, netix.dl, gigenet.dl,
-- zzip.sourceforge.net, and the project page — all 522, all zero-length).
-- The recipe therefore fetches Debian's "+dfsg" repack of the same upstream
-- 0.13.78 tarball, which is reachable. See stage1.md.
return recipe({
    version = "0.13.78",
    build = [[
        mkdir -p dl
        if [ ! -f dl/zziplib.tar.xz ]; then
          curl -fSL -C - -o dl/zziplib.tar.xz "https://deb.debian.org/debian/pool/main/z/zziplib/zziplib_0.13.78+dfsg.1.orig.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/zziplib.tar.xz -C src --strip-components=1
        mkdir -p $OUT/zziplib
        cp -r src/* $OUT/zziplib/
    ]]
})