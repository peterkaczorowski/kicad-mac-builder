include(ExternalProject)

ExternalProject_Add(
        ngspice
        PREFIX  ngspice
        GIT_REPOSITORY git://git.code.sf.net/p/ngspice/ngspice
        GIT_TAG ngspice-31.3
        UPDATE_COMMAND      ""
        PATCH_COMMAND       ""
        CONFIGURE_COMMAND ./autogen.sh
        COMMAND ./configure --prefix=${ngspice_INSTALL_DIR} --with-ngshared --enable-xspice --enable-cider --disable-debug LDFLAGS=-L/usr/local/opt/bison/lib
        BUILD_COMMAND  PATH=/usr/local/opt/bison/bin:$ENV{PATH} ${CMAKE_MAKE_PROGRAM} -j16
        BUILD_IN_SOURCE 1
        INSTALL_COMMAND make install
)
