// Stub implementation of scripta logger for Docker builds
// scripta is an UltiMaker-specific logging library not available in ConanCenter
// This stub provides empty implementations so the code compiles without scripta

#pragma once

#include <cstddef>
#include <string>

namespace scripta {

enum class SectionType {
    NA,
    INFILL,
    SUPPORT,
    WALLS,
    SKIN
};

// Stub implementations - all functions do nothing
// Overloads to handle different call patterns (const char*, std::string, etc.)
template<typename T, typename... Args>
void log(const char*, const T&, Args&&...) {
    // No-op - scripta logging disabled
}

template<typename... Args>
void log(const char*, Args&&...) {
    // No-op - scripta logging disabled
}

// Overloads accepting std::string as first argument (e.g., from fmt::format)
template<typename T, typename... Args>
void log(const std::string&, const T&, Args&&...) {
    // No-op - scripta logging disabled
}

template<typename... Args>
void log(const std::string&, Args&&...) {
    // No-op - scripta logging disabled
}

template<typename... Args>
void setAll(Args&&...) {
    // No-op - scripta logging disabled
}

// Stub types for compatibility
// These need to accept member pointers, lambdas, and regular pointers
template<typename T>
struct CellVDI {
    const char* name;
    T accessor;
    
    // Constructor to enable CTAD (class template argument deduction)
    CellVDI(const char* n, T a) : name(n), accessor(a) {}
};

// Deduction guide for CellVDI
template<typename T>
CellVDI(const char*, T) -> CellVDI<T>;

template<typename T>
struct PointVDI {
    const char* name;
    T accessor;
    
    // Constructor to enable CTAD
    PointVDI(const char* n, T a) : name(n), accessor(a) {}
};

// Deduction guide for PointVDI
template<typename T>
PointVDI(const char*, T) -> PointVDI<T>;

} // namespace scripta

