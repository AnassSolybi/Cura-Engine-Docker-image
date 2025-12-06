# syntax=docker/dockerfile:1.4
# Multi-stage Dockerfile for CuraEngine
# Optimized for cloud deployment with BuildKit cache mounts

# Dependencies stage - installs dependencies and can be cached separately
FROM ubuntu:22.04 AS deps

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Build optimization arguments
ARG BUILDKIT_INLINE_CACHE=1
ARG PARALLEL_JOBS=8
ARG CONAN_CPU_COUNT=8

# Set Conan CPU count for parallel builds
ENV CONAN_CPU_COUNT=${CONAN_CPU_COUNT}

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    pkg-config \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    protobuf-compiler \
    libprotobuf-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CMake 3.23+ from Kitware APT repository (required by libArcus)
RUN curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/kitware.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends cmake \
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

# Copy Conan configuration files
# Use Docker-specific conanfile that handles UltiMaker dependencies gracefully
COPY conanfile.docker.py ./conanfile.py
COPY conandata.yml ./

# Optionally add UltiMaker remote for packages (clipper, mapbox-wagyu, etc.)
# The Docker conanfile will gracefully fallback if the remote is unreachable
ARG ULTIMAKER_CONAN_REMOTE_URL=https://artifactory.ultimaker.com/artifactory/api/conan/conan-ultimaker
RUN if [ -n "$ULTIMAKER_CONAN_REMOTE_URL" ]; then \
        echo "Adding UltiMaker Conan remote: $ULTIMAKER_CONAN_REMOTE_URL"; \
        conan remote add ultimaker "$ULTIMAKER_CONAN_REMOTE_URL" 2>/dev/null || \
        (conan remote list 2>/dev/null | grep -q "ultimaker" && echo "UltiMaker remote already exists") || \
        echo "Note: Could not add UltiMaker remote (will use fallbacks)"; \
    fi; \
    echo "Testing UltiMaker remote connectivity..."; \
    if conan remote list 2>/dev/null | grep -q "ultimaker"; then \
        if ! timeout 5 curl -s --max-time 5 "$ULTIMAKER_CONAN_REMOTE_URL/v1/ping" > /dev/null 2>&1; then \
            echo "WARNING: UltiMaker remote is unreachable, removing it"; \
            conan remote remove ultimaker 2>/dev/null || true; \
            echo "UltiMaker remote removed - packages will be resolved from ConanCenter or built from source"; \
        else \
            echo "UltiMaker remote is reachable"; \
        fi; \
    fi; \
    echo "Configured Conan remotes:"; \
    conan remote list || echo "No remotes configured"

# Install dependencies with BuildKit cache mount for Conan cache
# This layer will be cached and reused when dependencies don't change
# Cache mount persists Conan packages across builds
# Create profile within the cache mount to ensure it's available
RUN --mount=type=cache,target=/root/.conan2 \
    echo "Creating Conan profile..."; \
    conan profile detect --force; \
    if ! conan remote list 2>/dev/null | grep -q "ultimaker"; then \
        echo "UltiMaker remote not available - using only ConanCenter remote"; \
        REMOTE_FLAG="--remote=conancenter"; \
    else \
        echo "UltiMaker remote available - will try all remotes"; \
        REMOTE_FLAG=""; \
    fi; \
    echo "Installing dependencies (Docker conanfile will handle UltiMaker packages with fallbacks)..."; \
    echo "Using ${CONAN_CPU_COUNT} parallel jobs for builds"; \
    conan install . --output-folder=build --build=missing $REMOTE_FLAG \
    -c tools.system.package_manager:mode=install \
    -c tools.system.package_manager:sudo=True \
    -c tools.build:jobs=${PARALLEL_JOBS} \
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

# Build stage - builds the actual application
FROM deps AS builder

# Copy source code (this layer invalidates when source changes)
COPY CMakeLists.txt CMakeLists.dependencies.cmake Cura.proto CuraEngine.ico CuraEngine.rc ./
COPY include ./include
COPY src ./src
COPY stubs ./stubs
# Note: benchmark, stress_benchmark, and tests are excluded as they're not needed for production build

# Build CuraEngine with all features enabled
# The Docker conanfile handles UltiMaker dependencies gracefully with fallbacks
# Re-run conan install to ensure all dependencies are available (they should be cached from deps stage)
# Then build the project using conan build
RUN --mount=type=cache,target=/root/.conan2 \
    echo "Ensuring Conan profile exists..."; \
    conan profile detect --force || true; \
    if ! conan remote list 2>/dev/null | grep -q "ultimaker"; then \
        REMOTE_FLAG="--remote=conancenter"; \
    else \
        REMOTE_FLAG=""; \
    fi; \
    echo "Re-installing dependencies to ensure they're available for build..."; \
    conan install . --output-folder=build --build=missing $REMOTE_FLAG \
    -c tools.system.package_manager:mode=install \
    -c tools.system.package_manager:sudo=True \
    -c tools.build:jobs=${PARALLEL_JOBS} \
    -o enable_arcus=True \
    -o enable_plugins=True \
    -o enable_remote_plugins=True \
    -o enable_benchmarks=False \
    -o enable_extensive_warnings=False \
    -s build_type=Release \
    -s compiler=gcc \
    -s compiler.version=12 \
    -s compiler.libcxx=libstdc++11 \
    -s compiler.cppstd=20 && \
    echo "Building CuraEngine..."; \
    conan build . --output-folder=build \
    -s build_type=Release \
    -s compiler=gcc \
    -s compiler.version=12 \
    -s compiler.libcxx=libstdc++11 \
    -s compiler.cppstd=20

# Find and copy the executable to a known location for the runtime stage
RUN find /build/build -name "CuraEngine" -type f -executable -exec cp {} /build/CuraEngine \; && \
    test -f /build/CuraEngine || (echo "Error: CuraEngine executable not found after build" && find /build/build -type f -name "*CuraEngine*" && exit 1)

# Runtime stage
FROM ubuntu:22.04 AS runtime

# Install runtime dependencies and Node.js
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libgcc-s1 \
    ca-certificates \
    curl \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user and directories
RUN useradd -m -u 1000 curaengine && \
    mkdir -p /app /data /app/server/uploads /app/server/outputs && \
    chown -R curaengine:curaengine /app /data

# Copy CuraEngine executable from builder (from known location)
COPY --from=builder /build/CuraEngine /app/CuraEngine

# Copy API server files
COPY server/ /app/server/

# Install Node.js dependencies for API server (as root, before switching user)
WORKDIR /app/server
RUN npm install --production && \
    npm cache clean --force

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh

# Copy required runtime libraries if any
# (Most dependencies should be statically linked, but we copy just in case)
RUN ldd /app/CuraEngine || true

# Make entrypoint executable and set ownership (before switching to non-root user)
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

