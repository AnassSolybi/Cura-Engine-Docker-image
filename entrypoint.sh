#!/bin/bash
# Entrypoint script for CuraEngine Docker container
# Supports both command-line and Arcus socket modes

set -e

# Default executable path
CURAENGINE_BIN="/app/CuraEngine"

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

# If no arguments provided, show help
if [ $# -eq 0 ]; then
    exec "$CURAENGINE_BIN" --help
    exit 0
fi

# Check if first argument is a command that CuraEngine recognizes
# If it starts with --, it's likely a CuraEngine option
# Otherwise, it might be a file path or other argument

# Execute CuraEngine with all provided arguments
exec "$CURAENGINE_BIN" "$@"

