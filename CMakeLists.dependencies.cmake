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
    message(STATUS "Fetching mapbox-wagyu from source...")
    FetchContent_Declare(
        mapbox_wagyu
        GIT_REPOSITORY https://github.com/mapbox/wagyu.git
        GIT_TAG        v0.5.0
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
    if(ENABLE_ARCUS)
        message(STATUS "Fetching libArcus from source...")
        FetchContent_Declare(
            arcus
            GIT_REPOSITORY https://github.com/Ultimaker/libArcus.git
            GIT_TAG        v5.11.0
            GIT_SHALLOW    TRUE
        )
        
        # Check if already populated
        FetchContent_GetProperties(arcus)
        if(NOT arcus_POPULATED)
            FetchContent_Populate(arcus)
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

