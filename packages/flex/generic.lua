require("m4")
require("flex@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/flex/* .
        # The bootstrap needs a runnable flex; the release ships the
        # generated parser, so skip it. Static with PIC, like the rest of
        # the prefix: flex's libfl is incidental to the tool, and a shared
        # libfl would need a loader path a target has no use for.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-bootstrap
        # doc/flex.1 ships in the tarball and doc/Makefile.am:4 lists it in
        # dist_man_MANS, but it is also MAINTAINERCLEANFILES (:5) and has a
        # regeneration rule (doc/Makefile.am:10) that runs help2man. This
        # release has no help2man and configure.ac:86 falls back to
        # build-aux/missing, so the rule fires, produces nothing, and
        # `make install` then dies on `install: cannot stat './flex.1'`. Its
        # prerequisites (configure.ac, src/flex.skl, src/options.c,
        # src/options.h) all land after it under `cp -r`. Touching it keeps
        # the shipped page; src/options.c and src/options.h are shipped
        # sources with no generating rule, so nothing re-touches them during
        # the build.
        touch doc/flex.1
        # tests/Makefile.am:451 does `include $(srcdir)/tableopts.am`, and
        # tableopts.am is itself generated (tests/Makefile.am:448
        # `tableopts.am: tableopts.sh`). automake therefore records it as a
        # prerequisite of the regeneration rule
        #   $(srcdir)/Makefile.in: $(srcdir)/Makefile.am $(srcdir)/tableopts.am ...
        # (tests/Makefile.in:1788). The tarball ships tableopts.am and
        # tableopts.sh with the SAME mtime (2017-05-04 06:16), so the include
        # is not out of date until `cp -r` gives the two distinct timestamps
        # in copy order and tableopts.sh lands newer. The rule then
        # regenerates tableopts.am, which is newer than tests/Makefile.in, so
        # the automake rule fires and demands the exact automake 1.15 that
        # generated this tarball (aclocal.m4 `am__api_version='1.15'`).
        # Touching tableopts.am makes it newer than tableopts.sh, so nothing
        # is regenerated and that rule stays quiet. Touch it before the
        # Makefile.in sweep below so Makefile.in ends up newest of all.
        touch aclocal.m4 configure src/config.h.in tests/tableopts.am
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
