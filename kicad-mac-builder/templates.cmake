ExternalProject_Add(
        templates
        PREFIX  templates
        GIT_REPOSITORY ${TEMPLATES_URL}
        GIT_TAG ${TEMPLATES_TAG}
        CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=<BINARY_DIR>/output"
)
