-- i2pd 2.61.0, fetch only.
--
-- Upstream's canonical home is GitHub (github.com/PurpleI2P/i2pd); the README
-- badge points at /releases/latest and the Arch PKGBUILD sources the GitHub
-- archive tarball. The GitLab project the project used to live on,
-- gitlab.com/P2PFoundation/i2pd, no longer exists on gitlab.com (see
-- stage1.md, "Upstream home: GitLab is gone"); there is nothing to fall back
-- to there.
--
-- 2.61.0 is the newest tag AND the newest published release; they agree, so
-- the tag is what the tarball URL names. The download is byte-identical to the
-- one Arch verifies for pkgver 2.61.0 (stage1.md records the sha256 match).
return recipe({
    version = "2.61.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/i2pd-$version.tar.gz ]; then
          curl -fSL -C - -o dl/i2pd-$version.tar.gz "https://github.com/PurpleI2P/i2pd/archive/$version/i2pd-$version.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        # The archive has exactly one top-level directory, i2pd-2.61.0/.
        tar -xzf dl/i2pd-$version.tar.gz -C src --strip-components=1
        mkdir -p $OUT/i2pd
        cp -r src/* $OUT/i2pd/
    ]]
})
