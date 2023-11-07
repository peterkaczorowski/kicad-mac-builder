include(ExternalProject)

if (NOT DEFINED KICAD_CMAKE_BUILD_TYPE )
    message( FATAL_ERROR "KICAD_CMAKE_BUILD_TYPE must be set.  Please see the README or try build.py." )
elseif ( KICAD_CMAKE_BUILD_TYPE STREQUAL "Release" )
    set(wxwidgets_MAKE_ARGS "BUILD=debug")
else ( ) # assume debug
    set(wxwidgets_MAKE_ARGS "BUILD=debug")
endif()


ExternalProject_Add(
    wxwidgets
    PREFIX  wxwidgets
    GIT_REPOSITORY https://gitlab.com/kicad/code/wxWidgets.git
    GIT_TAG kicad/macos-wx-3.2
    CONFIGURE_COMMAND   CPPFLAGS=-D__ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES=1 MAC_OS_X_VERSION_MIN_REQUIRED=${MACOS_MIN_VERSION} CC=clang CXX=clang++ ./configure
                        --prefix=${wxwidgets_INSTALL_DIR}
                        --with-macosx-version-min=${MACOS_MIN_VERSION}
                        --enable-unicode
                        --with-osx_cocoa
                        --enable-sound
                        --enable-graphics_ctx
                        --enable-display
                        --enable-geometry
                        --enable-debug_flag
                        --enable-debug
                        --enable-optimise
                        --disable-debugreport
                        --enable-uiactionsim
                        --enable-autoidman
                        --enable-monolithic
                        --enable-aui
                        --enable-html
                        --disable-stl
                        --enable-richtext
                        --disable-mediactrl
                        --with-libjpeg=builtin
                        --with-libpng=builtin
                        --with-regex=builtin
                        --with-libtiff=builtin
                        --with-zlib=builtin
                        --with-expat=builtin
                        --without-liblzma
                        --with-opengl
    UPDATE_COMMAND ""
    BUILD_COMMAND make ${wxwidgets_MAKE_ARGS}
    BUILD_IN_SOURCE 1
 )

ExternalProject_Get_Property(wxwidgets SOURCE_DIR)
set( wxwidgets_SOURCE_DIR ${SOURCE_DIR})

# In November 2023, the wxpython website went down for an extended period of time, and we
# needed to use our own copies of doxygen and waf

# If we have WAF set in the environment, it'll be passed through automatically
ExternalProject_Add(
    wxpython
    DEPENDS python wxwidgets
    BUILD_IN_SOURCE     1
    GIT_REPOSITORY https://github.com/wxWidgets/Phoenix.git
    GIT_TAG 371101db7a010d679d214fde617dae9de02008d9
    UPDATE_COMMAND      ""
    PATCH_COMMAND       ""
    CONFIGURE_COMMAND   ""
    BUILD_COMMAND WXWIN=${wxwidgets_SOURCE_DIR} MAC_OS_X_VERSION_MIN_REQUIRED=${MACOS_MIN_VERSION} ${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/bin/python3 build.py --use_syswx --prefix=${wxwidgets_INSTALL_DIR} touch etg --nodoc sip build_py
    INSTALL_COMMAND MAC_OS_X_VERSION_MIN_REQUIRED=${MACOS_MIN_VERSION} ${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/bin/python3 build.py install_py --prefix=${wxwidgets_INSTALL_DIR} # --nodoc
    COMMAND rm -f ${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/lib/site-packages/wx/libwx*.dylib # TODO: see if this is still needed
)

# If we have our own doxygen, we don't need to download one through wxpython's build process
# the regen.sh script expects a DOXYGEN environment variable to be set
if(DEFINED ENV{DOXYGEN})
    ExternalProject_Add_Step(
        wxpython
        prep_dox
        COMMENT "Generating wxwidgets XML with doyxgen"
        DEPENDERS build
        WORKING_DIRECTORY ${wxwidgets_SOURCE_DIR}/docs/doxygen
        COMMAND WX_SKIP_DOXYGEN_VERSION_CHECK=1 ./regen.sh xml
    )
else()
    ExternalProject_Add_Step(
        wxpython
        download_and_prep_dox
        COMMENT "Downloading doxygen and generating wxwidgets XML"
        DEPENDERS build
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMAND MAC_OS_X_VERSION_MIN_REQUIRED=${MACOS_MIN_VERSION} ${PYTHON_INSTALL_DIR}/Python.framework/Versions/Current/bin/python3 -c "import build$<SEMICOLON> build.getDoxCmd()"
        COMMAND bash -c "if [ ! -e bin/doxygen ]$<SEMICOLON> then cd bin$<SEMICOLON> ln -s <SOURCE_DIR>/bin/doxygen-*-darwin doxygen$<SEMICOLON> fi" # This isn't great, would love to improve this
        COMMAND ${CMAKE_COMMAND} -E chdir ${wxwidgets_SOURCE_DIR}/docs/doxygen WX_SKIP_DOXYGEN_VERSION_CHECK=1 DOXYGEN=<SOURCE_DIR>/bin/doxygen ./regen.sh xml
    )
endif()