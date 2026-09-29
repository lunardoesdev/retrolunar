require("tzdata@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/tzdata/* .
        # The IANA release ships the zone *source* files; compiling them into
        # TZif binaries needs zic, which the Makefile runs at install time.
        # Left alone it would run the ./zic it just built with the target
        # compiler, i.e. an aarch64 binary on this x86-64 host, which is
        # exactly the emulated execution this build must never do. Pointing
        # ZIC at plain "zic" resolves the host build tool through PATH and
        # leaves the locally built zic unexecuted.
        make ZIC=zic TOPDIR="$OUT/usr" install
    ]]
})
