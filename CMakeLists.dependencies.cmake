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
                # Replace find_package(Protobuf ...) with version that uses FindProtobuf module
                # System protobuf from apt might not have CMake config files, so use FindProtobuf module
                # Handle both find_package(Protobuf ...) and find_package(protobuf ...)
                string(REGEX REPLACE 
                    "find_package\\(Protobuf[^)]*\\)"
                    "find_package(Protobuf REQUIRED MODULE)"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Also handle lowercase protobuf
                string(REGEX REPLACE 
                    "find_package\\(protobuf[^)]*REQUIRED[^)]*\\)"
                    "find_package(Protobuf REQUIRED MODULE)"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # After FindProtobuf, ensure include directories are set correctly for compiler headers
                # Insert code after find_package(Protobuf) to verify and fix include paths
                string(REGEX REPLACE 
                    "(find_package\\(Protobuf REQUIRED MODULE\\))"
                    "\\1\n    # Ensure /usr/include is in Protobuf_INCLUDE_DIRS for compiler headers\n    # On Ubuntu/Debian, libprotobuf-dev installs headers to /usr/include/google/protobuf/\n    if(Protobuf_INCLUDE_DIRS)\n        list(FIND Protobuf_INCLUDE_DIRS \"/usr/include\" PROTOBUF_HAS_USR_INCLUDE)\n        if(PROTOBUF_HAS_USR_INCLUDE EQUAL -1)\n            list(APPEND Protobuf_INCLUDE_DIRS \"/usr/include\")\n            message(STATUS \"Added /usr/include to Protobuf_INCLUDE_DIRS for compiler headers\")\n        endif()\n    else()\n        set(Protobuf_INCLUDE_DIRS \"/usr/include\")\n        message(STATUS \"Set Protobuf_INCLUDE_DIRS to /usr/include for compiler headers\")\n    endif()\n    # Also set Protobuf_INCLUDE_DIR (singular) for compatibility with older code\n    if(NOT Protobuf_INCLUDE_DIR)\n        list(GET Protobuf_INCLUDE_DIRS 0 Protobuf_INCLUDE_DIR)\n    endif()\n    # Set PROTOBUF_INCLUDE_DIR (all caps) for compatibility\n    if(NOT PROTOBUF_INCLUDE_DIR)\n        set(PROTOBUF_INCLUDE_DIR ${Protobuf_INCLUDE_DIR})\n    endif()"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Replace set_project_warnings calls (from standardprojectsettings) with stub
                # This function is provided by standardprojectsettings, so we need to stub it
                # Comment out any calls to set_project_warnings
                string(REGEX REPLACE 
                    "([ \t]*)set_project_warnings\\([^\\)]*\\)"
                    "\\1# set_project_warnings(...)  # Disabled - using stub (standardprojectsettings not available)"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Add stub function definitions at the beginning if standardprojectsettings is not found
                string(REPLACE 
                    "if(NOT standardprojectsettings_FOUND)\n    message(STATUS \"standardprojectsettings not found - using fallback for libArcus\")\n    # Provide minimal fallback - libArcus may work without it\nendif()"
                    "if(NOT standardprojectsettings_FOUND)\n    message(STATUS \"standardprojectsettings not found - using fallback for libArcus\")\n    # Provide stub functions for standardprojectsettings functions\n    function(set_project_warnings)\n        # Stub - do nothing (warnings are optional)\n    endfunction()\n    function(enable_sanitizers)\n        # Stub - do nothing (sanitizers are optional)\n    endfunction()\n    function(use_threads)\n        # Stub - just find Threads package (standard CMake)\n        find_package(Threads QUIET)\n    endfunction()\nendif()"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Comment out enable_sanitizers calls
                string(REGEX REPLACE 
                    "([ \t]*)enable_sanitizers\\([^\\)]*\\)"
                    "\\1# enable_sanitizers(...)  # Disabled - using stub (standardprojectsettings not available)"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Comment out use_threads calls
                string(REGEX REPLACE 
                    "([ \t]*)use_threads\\([^\\)]*\\)"
                    "\\1# use_threads(...)  # Disabled - using stub (standardprojectsettings not available)"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Patch target_include_directories to ensure /usr/include is included for protobuf compiler headers
                # libArcus uses ${PROTOBUF_INCLUDE_DIR} which might not include /usr/include
                # Handle multiline target_include_directories calls
                string(REGEX REPLACE 
                    "(\\$\\{PROTOBUF_INCLUDE_DIR\\})"
                    "\\1\n    /usr/include"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Also handle the case where it uses Protobuf_INCLUDE_DIR (mixed case)
                string(REGEX REPLACE 
                    "(\\$\\{Protobuf_INCLUDE_DIR\\})"
                    "\\1\n    /usr/include"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Also handle Protobuf_INCLUDE_DIRS (plural)
                string(REGEX REPLACE 
                    "(\\$\\{Protobuf_INCLUDE_DIRS\\})"
                    "\\1\n    /usr/include"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                file(WRITE "${ARCUS_CMAKE_FILE}" "${ARCUS_CMAKE_CONTENT}")
                message(STATUS "Patched libArcus CMakeLists.txt to make standardprojectsettings optional and handle protobuf")
            endif()
            # Define stub functions in parent scope before adding subdirectory
            # This ensures they're available when libArcus's CMakeLists.txt is processed
            if(NOT COMMAND set_project_warnings)
                function(set_project_warnings)
                    # Stub function - do nothing (warnings are optional)
                endfunction()
            endif()
            if(NOT COMMAND enable_sanitizers)
                function(enable_sanitizers)
                    # Stub function - do nothing (sanitizers are optional)
                endfunction()
            endif()
            if(NOT COMMAND use_threads)
                function(use_threads)
                    # Stub function - just find Threads package (standard CMake)
                    find_package(Threads QUIET)
                endfunction()
            endif()
            # libArcus should have its own CMakeLists.txt
            # Add it as a subdirectory
            add_subdirectory(${arcus_SOURCE_DIR} ${arcus_BINARY_DIR} EXCLUDE_FROM_ALL)
            # Ensure /usr/include is in the Arcus target's include directories for protobuf compiler headers
            if(TARGET Arcus)
                target_include_directories(Arcus PUBLIC /usr/include)
                message(STATUS "Added /usr/include to Arcus target include directories for protobuf compiler headers")
            endif()
            # Create alias arcus::arcus for the Arcus target (libArcus creates target named "Arcus")
            if(TARGET Arcus AND NOT TARGET arcus::arcus)
                add_library(arcus::arcus ALIAS Arcus)
                message(STATUS "Created alias arcus::arcus for Arcus target")
            endif()
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

