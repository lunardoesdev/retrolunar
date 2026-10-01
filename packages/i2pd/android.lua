-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe.
--
-- This file exists for one reason:
-- Every Android system puts -DANDROID into the C++ compile: the 64-bit ones
-- in $CXXFLAGS (packages/aarch64-android35/generic.lua:69), the 32-bit and
-- x86_64 ones in $CFLAGS, which they then copy into $CXXFLAGS
-- (packages/armv7a-android35/generic.lua:63-64, packages/i686-android35/
-- generic.lua:63-64, packages/x86_64-android35/generic.lua:63-64). i2pd
-- branches on that exact macro in a way that silently disables the daemon.
-- See the comment on the export below.
require("i2pd@source")
require("openssl")
require("zlib")
require("boost")

return recipe({
    build = [[
        cp -r $NESTDIR/source/i2pd/* .

        # Upstream's own opt-out from its JNI daemon stub. daemon/Daemon.h:100
        # is
        #     #elif (defined(ANDROID) && !defined(ANDROID_BINARY))
        #         #define Daemon i2p::util::DaemonAndroid::Instance()
        # and DaemonAndroid (Daemon.h:102-112) is, in upstream's own comment, a
        # "dummy, invoked from android/jni/DaemonAndroid.*". It overrides none
        # of Daemon_Singleton's virtuals (Daemon.h:27-33), so daemon/i2pd.cpp:
        # 28-34 still compiles and still links -- against the base class's
        # definitions in daemon/Daemon.cpp. Nothing fails; the installed binary
        # just starts and does nothing. Defining ANDROID_BINARY alongside
        # ANDROID takes the #else arm at Daemon.h:113, which is the real Unix
        # daemon, and additionally re-enables the graceful-shutdown paths
        # gated at daemon/HTTPServer.cpp:836, :1420 and :1429, all of which are
        # `(!defined(ANDROID) ...) || defined(ANDROID_BINARY)`.
        #
        # CXXFLAGS is appended to and re-exported, never replaced: cmake copies
        # $CXXFLAGS into CMAKE_CXX_FLAGS when it creates that cache entry on the
        # first configure (verified: configuring the Android toolchain file
        # with CXXFLAGS="-O2 -fPIC -I/somewhere/include -DANDROID" reports
        # CMAKE_CXX_FLAGS=[-O2 -fPIC -I/somewhere/include -DANDROID]), and
        # passing -DCMAKE_CXXFLAGS on the command line would pre-create the
        # entry and make cmake ignore $CXXFLAGS entirely.
        export CXXFLAGS="$CXXFLAGS -DANDROID_BINARY"

        # See generic.lua for the reasoning behind each of these three.
        # BUILD_TESTING=OFF is the one that is load-bearing rather than
        # merely explicit: tests/CMakeLists.txt:2 requires the Check framework
        # and tests/CMakeLists.txt:111-123 registers thirteen add_test() rules
        # that RUN the freshly built test binaries. A test target that wants to
        # run is not acceptable in this repository, and the host has
        # qemu-aarch64 registered via binfmt_misc, so an unguarded test binary
        # would be runnable by accident.
        cmake -S build -B cmakebuild $CMAKE_FLAGS \
            -DWITH_UPNP=OFF \
            -DWITH_GIT_VERSION=OFF \
            -DBUILD_TESTING=OFF
        cmake --build cmakebuild --parallel 1
        cmake --install cmakebuild

        mkdir -p $OUT/etc/i2pd/tunnels.conf.d
        cp contrib/i2pd.conf contrib/subscriptions.txt contrib/tunnels.conf $OUT/etc/i2pd/
        mkdir -p $OUT/share/doc/i2pd
        cp ChangeLog LICENSE README.md contrib/i2pd.conf contrib/subscriptions.txt contrib/tunnels.conf $OUT/share/doc/i2pd/
        mkdir -p $OUT/share/i2pd
        cp -r contrib/certificates $OUT/share/i2pd/
        mkdir -p $OUT/share/man/man1
        cp debian/i2pd.1 $OUT/share/man/man1/
        # The headers are flattened into one directory; see generic.lua for the
        # verification that every quoted include still resolves.
        mkdir -p $OUT/include/i2pd
        cp i18n/*.h libi2pd/*.h libi2pd_client/*.h $OUT/include/i2pd/
        mkdir -p $OUT/var/lib/i2pd
        ln -sf ../../../share/i2pd/certificates $OUT/var/lib/i2pd/certificates
        ln -sf ../../../etc/i2pd/tunnels.conf.d $OUT/var/lib/i2pd/tunnels.d
        ln -sf ../../../etc/i2pd/i2pd.conf $OUT/var/lib/i2pd/i2pd.conf
        ln -sf ../../../etc/i2pd/subscriptions.txt $OUT/var/lib/i2pd/subscriptions.txt
        ln -sf ../../../etc/i2pd/tunnels.conf $OUT/var/lib/i2pd/tunnels.conf
    ]]
})
