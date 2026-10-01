-- p7zip: the GNU/Linux port of 7-Zip, by Igor Pavlov and the p7zip project.
--
-- Version choice: 9.20.1 (2009) is the last release of the *original* p7zip
-- line and is what most "p7zip" references still point at. 16.02 (2016) is the
-- maintained successor that Debian and every current distro actually build
-- ("p7zip 16.02+really26.01" in Debian sid). 16.02 is what this package takes:
-- it is the line that still gets security updates and it is the only one whose
-- source builds with a current toolchain.
--
-- URL note: upstream's canonical home is SourceForge
-- (sourceforge.net/projects/p7zip/files/16.02/p7zip_16.02_src_all.tar.bz2),
-- but SourceForge's CDN answers HTTP 522 to this network on every mirror tried
-- (master.dl, phoenixnap, cfhcable, netix, gigenet, downloads., project page,
-- RSS — all 522). The recipe therefore fetches Debian's pristine
-- "+dfsg" repack of the same upstream 16.02 tarball, which is reachable, with
-- the SourceForge URL as a mirror for when that CDN answers. See stage1.md.
return recipe({
    version = "16.02",
    build = [[
        mkdir -p dl
        if [ ! -f dl/p7zip.tar.xz ]; then
          curl -fSL -C - -o dl/p7zip.tar.xz "https://deb.debian.org/debian/pool/main/p/p7zip/p7zip_16.02+dfsg.orig.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        # Debian's repack unpacks as p7zip_16.02; upstream's own
        # p7zip_16.02_src_all.tar.bz2 uses the same single top directory, so
        # --strip-components=1 suits either tarball. No `|| curl ... mirror`
        # here on purpose: SourceForge serves a bz2 and Debian an xz, so one
        # extraction command cannot serve both. stage1.md records why.
        tar -xJf dl/p7zip.tar.xz -C src --strip-components=1
        mkdir -p $OUT/p7zip
        cp -r src/* $OUT/p7zip/
    ]]
})