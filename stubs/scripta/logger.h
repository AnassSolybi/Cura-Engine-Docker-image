// Stub implementation of scripta logger for Docker builds
// scripta is an UltiMaker-specific logging library not available in ConanCenter
// This stub provides empty implementations so the code compiles without scripta

#pragma once

#include <cstddef>

namespace scripta {

enum class SectionType {
    NA,
    INFILL,
    SUPPORT,
    WALLS,
    SKIN
};

// Stub implementations - all functions do nothing
// Overloads to handle different call patterns
template<typename T, typename... Args>
void log(const char*, const T&, Args&&...) {
    // No-op - scripta logging disabled
}

template<typename... Args>
void log(const char*, Args&&...) {
    // No-op - scripta logging disabled
}

template<typename... Args>
void setAll(Args&&...) {
    // No-op - scripta logging disabled
}

// Stub types for compatibility
template<typename T>
struct CellVDI {
    const char* name;
    T* value;
};

template<typename T>
struct PointVDI {
    const char* name;
    T* value;
};

} // namespace scripta

