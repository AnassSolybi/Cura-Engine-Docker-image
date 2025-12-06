# Multi-stage Dockerfile for CuraEngine
# Build stage
FROM ubuntu:22.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3 \
    python3-pip \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Conan 2.7.0+
RUN pip3 install --no-cache-dir "conan>=2.7.0"

# Install GCC 12 (Ubuntu 22.04 has GCC 11 by default, need to add repository for GCC 12)
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update && apt-get install -y \
    gcc-12 \
    g++-12 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100 \
    && rm -rf /var/lib/apt/lists/*

# Verify compiler version
RUN gcc --version && g++ --version

# Set working directory
WORKDIR /build

# Copy patching script first
COPY patch_conanfile.py ./

# Copy Conan configuration files
COPY conanfile.py conandata.yml ./

# Patch conanfile.py to remove UltiMaker python_requires dependencies
# This is necessary because the UltiMaker Conan remote is often unreachable from Docker builds
# Sentry support will be disabled, but CuraEngine will build successfully
# IMPORTANT: This must happen BEFORE any conan commands, as python_requires are resolved at recipe load time
RUN echo "Patching conanfile.py to work without UltiMaker python_requires (sentrylibrary/npmpackage)..."; \
    python3 patch_conanfile.py conanfile.py || (echo "ERROR: Failed to patch conanfile.py" && cat patch_conanfile.py && exit 1); \
    echo "conanfile.py patched successfully. Verifying patch..."; \
    grep -q "# python_requires" conanfile.py && echo "Patch verified: python_requires commented out" || echo "WARNING: Patch may not have worked correctly"

# Optionally add UltiMaker remote for other packages (clipper, mapbox-wagyu, etc.)
# These may still be needed, but python_requires are now optional
ARG ULTIMAKER_CONAN_REMOTE_URL=https://artifactory.ultimaker.com/artifactory/api/conan/conan-ultimaker
RUN if [ -n "$ULTIMAKER_CONAN_REMOTE_URL" ]; then \
        echo "Adding UltiMaker Conan remote for other packages: $ULTIMAKER_CONAN_REMOTE_URL"; \
        conan remote add ultimaker "$ULTIMAKER_CONAN_REMOTE_URL" 2>/dev/null || \
        (conan remote list 2>/dev/null | grep -q "ultimaker" && echo "UltiMaker remote already exists") || \
        echo "Note: Could not add UltiMaker remote (may require authentication)"; \
    fi; \
    echo "Configured Conan remotes:"; \
    conan remote list || echo "No remotes configured"

# Create Conan profile with GCC 12
RUN conan profile detect --force

# Copy source code
COPY CMakeLists.txt Cura.proto CuraEngine.ico CuraEngine.rc ./
COPY include ./include
COPY src ./src
# Note: benchmark, stress_benchmark, and tests are excluded as they're not needed for production build

# Build CuraEngine with all features enabled
# First, install dependencies
RUN conan install . --output-folder=build --build=missing \
    -c tools.system.package_manager:mode=install \
    -c tools.system.package_manager:sudo=True \
    -o enable_arcus=True \
    -o enable_plugins=True \
    -o enable_remote_plugins=True \
    -o enable_benchmarks=False \
    -o enable_extensive_warnings=False \
    -s build_type=Release \
    -s compiler=gcc \
    -s compiler.version=12 \
    -s compiler.libcxx=libstdc++11 \
    -s compiler.cppstd=20

# Then build the project using Conan
RUN conan build . --output-folder=build

# Find and copy the executable to a known location for the runtime stage
RUN find /build/build -name "CuraEngine" -type f -executable -exec cp {} /build/CuraEngine \; && \
    test -f /build/CuraEngine || (echo "Error: CuraEngine executable not found after build" && find /build/build -type f -name "*CuraEngine*" && exit 1)

# Runtime stage
FROM ubuntu:22.04 AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libgcc-s1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 curaengine && \
    mkdir -p /app /data && \
    chown -R curaengine:curaengine /app /data

# Copy CuraEngine executable from builder (from known location)
COPY --from=builder /build/CuraEngine /app/CuraEngine

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh

# Copy required runtime libraries if any
# (Most dependencies should be statically linked, but we copy just in case)
RUN ldd /app/CuraEngine || true

# Make entrypoint executable and set ownership
RUN chmod +x /app/entrypoint.sh && \
    chown -R curaengine:curaengine /app

# Set working directory
WORKDIR /app

# Switch to non-root user
USER curaengine

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command (can be overridden)
CMD ["--help"]

