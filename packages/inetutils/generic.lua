require("inetutils@source")
require("ncurses")

return recipe({
    build = [[
        cp -r $NESTDIR/source/inetutils/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --bindir=/usr/bin \
            --localstatedir=/var \
            --disable-logger \
            --disable-whois \
            --disable-rcp \
            --disable-rexec \
            --disable-rlogin \
            --disable-rsh \
            --disable-servers
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # telnet/sys_bsd.c is the only file in the tree that uses struct termios
        # and the tcgetattr/tcsetattr/cfgetospeed/cfgetispeed family without
        # including <termios.h>: glibc pulls that in transitively, Bionic does
        # not. A forced include fixes it without touching the upstream source.
        #
        # The header pulls config.h in first, because gnulib refuses to be
        # included before config.h and a bare "-include termios.h" would land
        # ahead of it ("../lib/sys/types.h:28:3: error: Please include
        # config.h first.").
        cat > termios-first.h <<'EOF'
        #include <config.h>
        #include <termios.h>
        EOF
        # The top-level make walks SUBDIRS in order and telnet links
        # ../libtelnet/libtelnet.a, so those libraries are built first. telnet's
        # own AM_CPPFLAGS is restated because a command-line assignment would
        # otherwise replace it and drop -I../libinetutils.
        make -C lib
        make -C libinetutils
        make -C libtelnet
        make -C libicmp
        make -C libls
        make -C telnet AM_CPPFLAGS="-DTERMCAP -DLINEMODE -DKLUDGELINEMODE -DENV_HACK -I. -I.. -I../lib -I../libinetutils -include ../termios-first.h"
        make
        make install
        # LFS moves ifconfig from sbin to bin; $OUT/sbin holds it, so link it
        # next to the other user-facing programs instead of using mv.
        ln -s ../sbin/ifconfig $OUT/bin/ifconfig
    ]]
})
