include(ExternalProject)

if (NOT DEFINED KICAD_CMAKE_BUILD_TYPE )
	message( FATAL_ERROR "KICAD_CMAKE_BUILD_TYPE must be set.  Please see the README or try build.py." )
elseif ( KICAD_CMAKE_BUILD_TYPE STREQUAL "Release" )
	set(wxwdgets_MAKE_ARGS BUILD=release)
else ( ) # assume debug
	set(wxwdgets_MAKE_ARGS "")
endif()

ExternalProject_Add(
        wxwidgets
        PREFIX  wxwidgets
        GIT_REPOSITORY https://gitlab.com/kicad/code/wxWidgets.git
        GIT_TAG   kicad/macos-wx-3.0
        CONFIGURE_COMMAND   CPPFLAGS=-D__ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES=1 MAC_OS_X_VERSION_MIN_REQUIRED=${MACOS_MIN_VERSION} ./configure
                            --prefix=${wxwidgets_INSTALL_DIR}
                            --with-opengl
                            --enable-monolithic
                            --enable-aui
                            --enable-html
                            --enable-stl
			    --enable-richtext
                            --disable-mediactrl
                            --with-libjpeg=builtin
                            --with-libpng=builtin
                            --with-regex=builtin
                            --with-libtiff=builtin
                            --with-zlib=builtin
                            --with-expat=builtin
                            --without-liblzma
                            --with-macosx-version-min=${MACOS_MIN_VERSION}
                            CC=clang
                            CXX=clang++
        UPDATE_COMMAND ""
	BUILD_COMMAND ${MAKE} ${wxwidgets_MAKE_ARGS}
        BUILD_IN_SOURCE 1
)

ExternalProject_Add(
        wxpython
        DEPENDS python wxwidgets
        URL ${WXPYTHON_URL}
        URL_HASH SHA1=${WXPYTHON_SHA1}
        UPDATE_COMMAND      ""
        PATCH_COMMAND       ""
        BUILD_IN_SOURCE     1
        CONFIGURE_COMMAND   ""
        BUILD_COMMAND MAC_OS_X_VERSION_MIN_REQUIRED=${MACOS_MIN_VERSION} ${PYTHON_INSTALL_DIR}/Python.framework/Versions/3.8/bin/python3.8 build.py build_py --use_syswx --prefix=${wxwidgets_INSTALL_DIR} --nodoc
        INSTALL_COMMAND MAC_OS_X_VERSION_MIN_REQUIRED=${MACOS_MIN_VERSION} ${PYTHON_INSTALL_DIR}/Python.framework/Versions/3.8/bin/python3.8 build.py install_py --prefix=${wxwidgets_INSTALL_DIR} --nodoc
        BUILD_IN_SOURCE 1
)

#TODO change build command to happen in wxpython directory
