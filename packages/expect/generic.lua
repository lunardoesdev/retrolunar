-- expect needs a Tcl library and headers for its LINK LINE, and a Tcl
-- interpreter for its BUILD-time script generation. Those are two different
-- Tcl installations and this recipe keeps them apart deliberately.
--
-- The interpreter: make install reaches $(SCRIPTS) through
-- install-libraries (Makefile.in:231), and $(SCRIPTS) runs
-- $(TCLSH) fixline1 to generate timed-run, timed-read, ftp-rfc, autopasswd,
-- lpunlock, weather and the rest (Makefile.in:35, :382-383). With
-- --with-tcl=$PREFIX/lib, TEA_PROG_TCLSH resolves TCLSH_PROG to
-- $PREFIX/bin/tclsh - the cross-compiled TARGET interpreter - so this would
-- execute an aarch64 binary on this x86-64 host, which is forbidden
-- outright. TCLSH_PROG is a plain '=' make variable (Makefile.in:172), so a
-- make command-line assignment overrides it and nothing else; the host
-- interpreter comes from tcl@native, which the loader puts on PATH and
-- exposes as $NATIVE_PREFIX.
--
-- The library and headers: --with-tcl also sets TCL_BIN_DIR, and
-- TEA_LOAD_TCLCONFIG then sources that directory's tclConfig.sh, which is
-- where TCL_LIB_SPEC, TCL_INCLUDE_SPEC and TCL_DEFS all come from
-- (tclconfig/tcl.m4:64-79, :357-360). Makefile.in:176 compiles every exp_*.c
-- with @TCL_INCLUDES@ and Makefile.in:396 links expect with @TCL_LIB_SPEC@.
-- So --with-tcl must stay on the TARGET prefix: pointing it at
-- $NATIVE_PREFIX would compile and link the aarch64 expect against x86-64
-- headers and libtcl, which is worse than the original problem because that
-- failure is silent. One lever cannot serve both jobs, so this recipe uses
-- --with-tcl for the link line and TCLSH_PROG for the interpreter.
--
-- Note the pkgIndex.tcl rule at Makefile.in:328-330 is the one that looks
-- alarming, but it is NOT in the install chain: `binaries` depends on
-- pkgIndex.tcl-hand (:217), which writes the file with plain shell echo and
-- runs no interpreter. install-lib-binaries only installs the file that
-- pkgIndex.tcl-hand already produced (:558-559).
require("tcl")
require("tcl@native")
require("expect@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/expect/* .
        # --with-tcl/--with-tclinclude stay on $PREFIX: this is the target Tcl,
        # and it is what supplies the headers exp_*.c is compiled against and
        # the TCL_LIB_SPEC expect is linked with. See the header comment for
        # why it must not point at $NATIVE_PREFIX.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --with-tcl="$PREFIX/lib" \
            --with-tclinclude="$PREFIX/include" \
            --enable-shared \
            --disable-rpath \
            --mandir="$OUT/share/man"
        # expect has no AC_CONFIG_HEADERS: configure.in:1058 is a bare
        # `touch expect_cf.h`, so no config template is named here. touch on a
        # missing file would succeed silently and leave the autoheader re-run
        # the guard exists to prevent live.
        touch aclocal.m4 configure
        find . -name 'Makefile.in' | xargs touch
        make -j1
        # TCLSH_PROG= on the make line is the whole fix for the interpreter:
        # Makefile.in:172 makes it an ordinary '=' variable, so a command-line
        # assignment overrides the configured value and leaves TCL_LIB_SPEC and
        # TCL_INCLUDES alone. tcl@native installs its interpreter as
        # bin/tclsh8.6 (tcl/unix/Makefile.in:816).
        make -j1 install TCLSH_PROG="$NATIVE_PREFIX/bin/tclsh8.6"
    ]]
})
