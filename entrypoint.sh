#!/bin/bash
# Entrypoint script for CuraEngine Docker container
# Supports command-line mode, Arcus socket mode, and API server mode

set -e

# Default executable path
CURAENGINE_BIN="/app/CuraEngine"
API_SERVER_DIR="/app/server"

# Function to handle signals
cleanup() {
    echo "Received signal, shutting down gracefully..."
    exit 0
}

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT

# Check if CuraEngine executable exists
if [ ! -f "$CURAENGINE_BIN" ]; then
    echo "Error: CuraEngine executable not found at $CURAENGINE_BIN"
    exit 1
fi

# Make sure it's executable
chmod +x "$CURAENGINE_BIN"

# Check if API server mode is requested
if [ "$1" = "api" ] || [ "$1" = "server" ] || [ "${RUN_API_SERVER}" = "true" ]; then
    echo "Starting CuraEngine API server..."
    if [ ! -d "$API_SERVER_DIR" ]; then
        echo "Error: API server directory not found at $API_SERVER_DIR"
        exit 1
    fi
    cd "$API_SERVER_DIR"
    # Ensure directories exist
    mkdir -p uploads outputs
    exec node server.js
fi

# If no arguments provided, show help
if [ $# -eq 0 ]; then
    exec "$CURAENGINE_BIN" --help
    exit 0
fi

# Execute CuraEngine with all provided arguments
exec "$CURAENGINE_BIN" "$@"

