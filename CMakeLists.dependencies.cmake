# CMakeLists.dependencies.cmake
# Bundles UltiMaker dependencies using FetchContent to avoid Conan remote dependency
# Copyright (c) 2024 Ultimaker B.V.
# CuraEngine is released under the terms of the AGPLv3 or higher.

include(FetchContent)

# Option to use bundled dependencies (default: ON for Docker builds)
option(USE_BUNDLED_DEPS "Use FetchContent to bundle dependencies instead of Conan packages" ON)

if(USE_BUNDLED_DEPS)
    message(STATUS "Using bundled dependencies via FetchContent")
    
    # Mapbox Geometry (dependency of wagyu)
    # Header-only library providing geometry primitives
    message(STATUS "Fetching mapbox-geometry from source...")
    FetchContent_Declare(
        mapbox_geometry
        GIT_REPOSITORY https://github.com/mapbox/geometry.hpp.git
        GIT_TAG        v2.0.3
        GIT_SHALLOW    TRUE
    )
    
    FetchContent_GetProperties(mapbox_geometry)
    if(NOT mapbox_geometry_POPULATED)
        FetchContent_Populate(mapbox_geometry)
        add_library(mapbox-geometry INTERFACE)
        target_include_directories(mapbox-geometry INTERFACE ${mapbox_geometry_SOURCE_DIR}/include)
        add_library(mapbox-geometry::mapbox-geometry ALIAS mapbox-geometry)
        set(MAPBOX_GEOMETRY_FETCHED TRUE)
        message(STATUS "mapbox-geometry fetched and configured successfully")
    else()
        set(MAPBOX_GEOMETRY_FETCHED TRUE)
        message(STATUS "mapbox-geometry already populated")
    endif()
    
    # Mapbox Wagyu
    # Mapbox Wagyu is a header-only library that depends on mapbox-geometry
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
        # Link to mapbox-geometry to get its include directories
        target_link_libraries(mapbox-wagyu INTERFACE mapbox-geometry)
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
                # Use a placeholder approach: first replace with placeholder, then replace placeholder with full implementation
                # This ensures we catch all variations of find_package(Protobuf ...) and find_package(protobuf ...)
                string(REGEX REPLACE 
                    "find_package\\([Pp]rotobuf[^)]*\\)"
                    "@PROTOBUF_FIND_PACKAGE_PLACEHOLDER@"
                    ARCUS_CMAKE_CONTENT
                    "${ARCUS_CMAKE_CONTENT}"
                )
                # Now replace the placeholder with the full implementation including include directory fix
                string(REPLACE 
                    "@PROTOBUF_FIND_PACKAGE_PLACEHOLDER@"
                    "find_package(Protobuf REQUIRED MODULE)\n    # Ensure /usr/include is in Protobuf_INCLUDE_DIRS for compiler headers\n    # On Ubuntu/Debian, libprotobuf-dev installs headers to /usr/include/google/protobuf/\n    if(Protobuf_INCLUDE_DIRS)\n        list(FIND Protobuf_INCLUDE_DIRS \"/usr/include\" PROTOBUF_HAS_USR_INCLUDE)\n        if(PROTOBUF_HAS_USR_INCLUDE EQUAL -1)\n            list(APPEND Protobuf_INCLUDE_DIRS \"/usr/include\")\n            message(STATUS \"Added /usr/include to Protobuf_INCLUDE_DIRS for compiler headers\")\n        endif()\n    else()\n        set(Protobuf_INCLUDE_DIRS \"/usr/include\")\n        message(STATUS \"Set Protobuf_INCLUDE_DIRS to /usr/include for compiler headers\")\n    endif()\n    # Also set Protobuf_INCLUDE_DIR (singular) for compatibility with older code\n    if(NOT Protobuf_INCLUDE_DIR)\n        list(GET Protobuf_INCLUDE_DIRS 0 Protobuf_INCLUDE_DIR)\n    endif()\n    # Set PROTOBUF_INCLUDE_DIR (all caps) for compatibility\n    if(NOT PROTOBUF_INCLUDE_DIR)\n        set(PROTOBUF_INCLUDE_DIR ${Protobuf_INCLUDE_DIR})\n    endif()"
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
            # Find protobuf in parent scope before adding libArcus subdirectory
            # This ensures protobuf targets are available when libArcus's CMakeLists.txt is processed
            find_package(Protobuf REQUIRED MODULE)
            # Ensure /usr/include is in Protobuf_INCLUDE_DIRS for compiler headers
            if(Protobuf_INCLUDE_DIRS)
                list(FIND Protobuf_INCLUDE_DIRS "/usr/include" PROTOBUF_HAS_USR_INCLUDE)
                if(PROTOBUF_HAS_USR_INCLUDE EQUAL -1)
                    list(APPEND Protobuf_INCLUDE_DIRS "/usr/include")
                    message(STATUS "Added /usr/include to Protobuf_INCLUDE_DIRS for compiler headers")
                endif()
            else()
                set(Protobuf_INCLUDE_DIRS "/usr/include")
                message(STATUS "Set Protobuf_INCLUDE_DIRS to /usr/include for compiler headers")
            endif()
            # Create protobuf::libprotobuf target if it doesn't exist
            if(NOT TARGET protobuf::libprotobuf)
                # Get the actual library path (handle list case)
                list(GET Protobuf_LIBRARIES 0 PROTOBUF_LIB_PATH)
                if(NOT PROTOBUF_LIB_PATH)
                    set(PROTOBUF_LIB_PATH ${Protobuf_LIBRARIES})
                endif()
                add_library(protobuf::libprotobuf SHARED IMPORTED)
                # Use target_include_directories to set include dirs (more reliable than set_target_properties)
                set_target_properties(protobuf::libprotobuf PROPERTIES
                    IMPORTED_LOCATION "${PROTOBUF_LIB_PATH}"
                )
                # Set include directories using target_include_directories (handles lists correctly)
                target_include_directories(protobuf::libprotobuf INTERFACE ${Protobuf_INCLUDE_DIRS})
                message(STATUS "Created protobuf::libprotobuf imported target with includes: ${Protobuf_INCLUDE_DIRS}")
            else()
                # If target already exists, ensure /usr/include is in its include directories
                get_target_property(EXISTING_PROTOBUF_INCLUDES protobuf::libprotobuf INTERFACE_INCLUDE_DIRECTORIES)
                if(EXISTING_PROTOBUF_INCLUDES)
                    list(FIND EXISTING_PROTOBUF_INCLUDES "/usr/include" PROTOBUF_TARGET_HAS_USR_INCLUDE)
                    if(PROTOBUF_TARGET_HAS_USR_INCLUDE EQUAL -1)
                        target_include_directories(protobuf::libprotobuf INTERFACE /usr/include)
                        message(STATUS "Added /usr/include to existing protobuf::libprotobuf target")
                    endif()
                else()
                    target_include_directories(protobuf::libprotobuf INTERFACE ${Protobuf_INCLUDE_DIRS})
                    message(STATUS "Set include directories on existing protobuf::libprotobuf target: ${Protobuf_INCLUDE_DIRS}")
                endif()
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
            # Also link to protobuf::libprotobuf to ensure protobuf includes are propagated
            if(TARGET Arcus)
                # Add /usr/include using PUBLIC so it's available both when building Arcus and when using it
                # This ensures the protobuf compiler headers are found during compilation
                target_include_directories(Arcus PUBLIC /usr/include)
                message(STATUS "Added /usr/include to Arcus target include directories for protobuf compiler headers")
                
                # Link to protobuf::libprotobuf to ensure protobuf includes are available
                # This should propagate the protobuf include directories from protobuf::libprotobuf
                if(TARGET protobuf::libprotobuf)
                    target_link_libraries(Arcus PUBLIC protobuf::libprotobuf)
                    message(STATUS "Linked Arcus target to protobuf::libprotobuf for include propagation")
                    # Verify protobuf::libprotobuf has correct includes
                    get_target_property(PROTOBUF_INTERFACE_INCLUDES protobuf::libprotobuf INTERFACE_INCLUDE_DIRECTORIES)
                    message(STATUS "protobuf::libprotobuf INTERFACE_INCLUDE_DIRECTORIES: ${PROTOBUF_INTERFACE_INCLUDES}")
                endif()
                
                # Debug: Show final include directories on Arcus target
                get_target_property(ARCUS_FINAL_INCLUDES Arcus INTERFACE_INCLUDE_DIRECTORIES)
                get_target_property(ARCUS_FINAL_PUBLIC_INCLUDES Arcus INCLUDE_DIRECTORIES)
                message(STATUS "Arcus INTERFACE_INCLUDE_DIRECTORIES: ${ARCUS_FINAL_INCLUDES}")
                message(STATUS "Arcus INCLUDE_DIRECTORIES: ${ARCUS_FINAL_PUBLIC_INCLUDES}")
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

