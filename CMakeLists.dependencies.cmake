# CMakeLists.dependencies.cmake
# Bundles UltiMaker dependencies using FetchContent to avoid Conan remote dependency
# Copyright (c) 2024 Ultimaker B.V.
# CuraEngine is released under the terms of the AGPLv3 or higher.

include(FetchContent)

# Option to use bundled dependencies (default: ON for Docker builds)
option(USE_BUNDLED_DEPS "Use FetchContent to bundle dependencies instead of Conan packages" ON)

if(USE_BUNDLED_DEPS)
    message(STATUS "Using bundled dependencies via FetchContent")
    
    # Mapbox Wagyu
    # Mapbox Wagyu is a header-only library
    # Note: The repository may not have a v0.5.0 tag, using a known working commit
    message(STATUS "Fetching mapbox-wagyu from source...")
    FetchContent_Declare(
        mapbox_wagyu
        GIT_REPOSITORY https://github.com/mapbox/wagyu.git
        GIT_TAG        0.5.0
        GIT_SHALLOW    TRUE
    )
    
    # Check if already populated
    FetchContent_GetProperties(mapbox_wagyu)
    if(NOT mapbox_wagyu_POPULATED)
        FetchContent_Populate(mapbox_wagyu)
        # Mapbox Wagyu is header-only, so we just need to add the include directory
        # The actual target will be created by find_package if needed, or we create it here
        add_library(mapbox-wagyu INTERFACE)
        target_include_directories(mapbox-wagyu INTERFACE ${mapbox_wagyu_SOURCE_DIR}/include)
        # Create alias for consistency with find_package
        add_library(mapbox-wagyu::mapbox-wagyu ALIAS mapbox-wagyu)
        set(MAPBOX_WAGYU_FETCHED TRUE)
        message(STATUS "mapbox-wagyu fetched and configured successfully")
    else()
        set(MAPBOX_WAGYU_FETCHED TRUE)
        message(STATUS "mapbox-wagyu already populated")
    endif()
    
    # Arcus (only if ENABLE_ARCUS is True)
    # Note: Using main branch as specific version tags may not exist
    if(ENABLE_ARCUS)
        message(STATUS "Fetching libArcus from source...")
        FetchContent_Declare(
            arcus
            GIT_REPOSITORY https://github.com/Ultimaker/libArcus.git
            GIT_TAG        main
            GIT_SHALLOW    TRUE
        )
        
        # Check if already populated
        FetchContent_GetProperties(arcus)
        if(NOT arcus_POPULATED)
            FetchContent_Populate(arcus)
            # Patch libArcus CMakeLists.txt to make standardprojectsettings optional and handle protobuf
            # This is needed because standardprojectsettings is UltiMaker-specific and not available in Docker builds
            # Also, system protobuf might not have CMake config files, so we use pkg-config as fallback
            set(ARCUS_CMAKE_FILE "${arcus_SOURCE_DIR}/CMakeLists.txt")
            if(EXISTS "${ARCUS_CMAKE_FILE}")
                file(READ "${ARCUS_CMAKE_FILE}" ARCUS_CMAKE_CONTENT)
                # Replace find_package(standardprojectsettings REQUIRED) with optional version
                string(REPLACE 
                    "find_package(standardprojectsettings REQUIRED)"
                    "find_package(standardprojectsettings QUIET)\nif(NOT standardprojectsettings_FOUND)\n    message(STATUS \"standardprojectsettings not found - using fallback for libArcus\")\n    # Provide minimal fallback - libArcus may work without it\nendif()"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Replace find_package(protobuf REQUIRED) with version that finds system protobuf manually
                # System protobuf from apt might not have CMake config files, so we find it manually
                string(REPLACE 
                    "find_package(protobuf REQUIRED)"
                    "find_package(protobuf QUIET)\nif(NOT protobuf_FOUND)\n    # System protobuf from apt might not have CMake config files, find manually\n    message(STATUS \"protobuf CMake config not found, searching for system protobuf...\")\n    # Use pkg-config to get paths (most reliable)\n    find_package(PkgConfig REQUIRED)\n    execute_process(\n        COMMAND pkg-config --variable=libdir protobuf\n        OUTPUT_VARIABLE PROTOBUF_PKG_LIBDIR\n        OUTPUT_STRIP_TRAILING_WHITESPACE\n        ERROR_QUIET\n    )\n    execute_process(\n        COMMAND pkg-config --variable=includedir protobuf\n        OUTPUT_VARIABLE PROTOBUF_PKG_INCLUDEDIR\n        OUTPUT_STRIP_TRAILING_WHITESPACE\n        ERROR_QUIET\n    )\n    # Find library - try pkg-config path first, then standard locations\n    if(PROTOBUF_PKG_LIBDIR)\n        find_library(PROTOBUF_LIBRARY NAMES protobuf libprotobuf PATHS \"${PROTOBUF_PKG_LIBDIR}\" NO_DEFAULT_PATH)\n    endif()\n    if(NOT PROTOBUF_LIBRARY)\n        # Try standard Ubuntu paths\n        find_library(PROTOBUF_LIBRARY NAMES protobuf libprotobuf PATHS /usr/lib/x86_64-linux-gnu /usr/lib /usr/local/lib)\n        # If still not found, try to find any libprotobuf.so* file directly\n        if(NOT PROTOBUF_LIBRARY)\n            file(GLOB PROTOBUF_LIB_CANDIDATES \"/usr/lib/x86_64-linux-gnu/libprotobuf.so*\" \"/usr/lib/libprotobuf.so*\")\n            if(PROTOBUF_LIB_CANDIDATES)\n                list(GET PROTOBUF_LIB_CANDIDATES 0 PROTOBUF_LIBRARY)\n            endif()\n        endif()\n    endif()\n    # Find include directory\n    if(PROTOBUF_PKG_INCLUDEDIR)\n        set(PROTOBUF_INCLUDE_DIR \"${PROTOBUF_PKG_INCLUDEDIR}\")\n    else()\n        find_path(PROTOBUF_INCLUDE_DIR google/protobuf/message.h PATHS /usr/include /usr/local/include)\n    endif()\n    # Find protoc executable\n    find_program(PROTOBUF_PROTOC_EXECUTABLE NAMES protoc PATHS /usr/bin /usr/local/bin)\n    if(PROTOBUF_LIBRARY AND PROTOBUF_INCLUDE_DIR AND PROTOBUF_PROTOC_EXECUTABLE)\n        message(STATUS \"Found system protobuf: LIB=${PROTOBUF_LIBRARY}, INC=${PROTOBUF_INCLUDE_DIR}, EXE=${PROTOBUF_PROTOC_EXECUTABLE}\")\n        # Create imported targets for protobuf\n        add_library(protobuf::libprotobuf SHARED IMPORTED)\n        set_target_properties(protobuf::libprotobuf PROPERTIES\n            IMPORTED_LOCATION \"${PROTOBUF_LIBRARY}\"\n            INTERFACE_INCLUDE_DIRECTORIES \"${PROTOBUF_INCLUDE_DIR}\"\n        )\n        set(protobuf_FOUND TRUE)\n        set(Protobuf_PROTOC_EXECUTABLE \"${PROTOBUF_PROTOC_EXECUTABLE}\")\n    else()\n        message(FATAL_ERROR \"protobuf not found - required for libArcus. LIB=${PROTOBUF_LIBRARY}, INC=${PROTOBUF_INCLUDE_DIR}, EXE=${PROTOBUF_PROTOC_EXECUTABLE}\")\n    endif()\nendif()"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                file(WRITE "${ARCUS_CMAKE_FILE}" "${ARCUS_CMAKE_CONTENT}")
                message(STATUS "Patched libArcus CMakeLists.txt to make standardprojectsettings optional and handle protobuf")
            endif()
            # libArcus should have its own CMakeLists.txt
            # Add it as a subdirectory
            add_subdirectory(${arcus_SOURCE_DIR} ${arcus_BINARY_DIR} EXCLUDE_FROM_ALL)
            set(ARCUS_FETCHED TRUE)
            message(STATUS "libArcus fetched successfully")
        else()
            set(ARCUS_FETCHED TRUE)
            message(STATUS "libArcus already populated")
        endif()
    else()
        set(ARCUS_FETCHED FALSE)
    endif()
    
    # Note: Clipper is more complex - the original library doesn't have CMake support
    # We'll let Conan handle clipper for now, or we can create a simple wrapper
    # Clipper source is available but would need manual CMake setup
    
else()
    message(STATUS "Using Conan packages for dependencies (USE_BUNDLED_DEPS=OFF)")
    set(MAPBOX_WAGYU_FETCHED FALSE)
    set(ARCUS_FETCHED FALSE)
endif()

