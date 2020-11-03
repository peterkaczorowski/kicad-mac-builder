ExternalProject_Add(
        footprints
        PREFIX  footprints
        GIT_REPOSITORY ${FOOTPRINTS_URL}
        GIT_TAG ${FOOTPRINTS_TAG}
        CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=<BINARY_DIR>/output"
)
