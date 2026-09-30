-- Only the GitHub *release asset* numactl-<ver>.tar.gz carries a generated
-- Makefile.in and config.h.in. The GitHub tag archive and the Debian
-- numactl_<ver>.orig.tar.gz both ship configure alone, so a build from
-- either of those would have to run automake/autoconf, which this prefix
-- does not do. Verified against v2.0.19.
return recipe({
    version = "2.0.19",
    build = [[
        mkdir -p dl
        if [ ! -f dl/numactl.tar.gz ]; then
          curl -fSL -C - -o dl/numactl.tar.gz "https://github.com/numactl/numactl/releases/download/v2.0.19/numactl-2.0.19.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/numactl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libnuma
        cp -r src/* $OUT/libnuma/
    ]]
})
