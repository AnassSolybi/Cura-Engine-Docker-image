# Docker Deployment Guide for CuraEngine

This guide explains how to build and deploy CuraEngine as a Docker container on a server.

## Prerequisites

- Docker 20.10 or later
- Docker Compose 2.0 or later (optional, for easier deployment)
- At least 8GB of available disk space for building
- At least 4GB of RAM recommended for building

## Building the Docker Image

### Basic Build

Build the Docker image from the project root:

```bash
docker build -t curaengine:latest .
```

### Build with Custom Tag

```bash
docker build -t curaengine:v5.12.0 .
```

### Build Arguments

The Dockerfile supports the following build argument:

- `ULTIMAKER_CONAN_REMOTE_URL`: URL for the UltiMaker Conan remote (default: `https://artifactory.ultimaker.com/artifactory/api/conan/conan-ultimaker`)

Example:
```bash
docker build --build-arg ULTIMAKER_CONAN_REMOTE_URL=https://your-ultimaker-remote-url.com -t curaengine:latest .
```

**Note:** The Docker build uses a Docker-specific Conan recipe (`conanfile.docker.py`) that handles UltiMaker dependencies gracefully. The build will:
1. Try to use UltiMaker packages if the remote is available
2. Automatically fallback to ConanCenter versions or build from source if UltiMaker remote is unreachable
3. Work without requiring UltiMaker remote access (packages will be built from source with `--build=missing`)

The Dockerfile currently builds with all features enabled:
- ARCUS communication: Enabled
- Plugins: Enabled
- Remote plugins: Enabled
- Benchmarks: Disabled (for production)
- Sentry support: Disabled (not needed for Docker deployments)

## Running the Container

### API Server Mode (Recommended)

The container includes a Node.js Express API server for HTTP-based slicing. This is the default mode when using docker-compose.

**Using Docker Compose:**
```bash
docker-compose up -d
```

The API server will be available at `http://localhost:3000`

**Using Docker Run:**
```bash
docker run -d \
  -p 3000:3000 \
  --name curaengine-api \
  curaengine:latest api
```

**API Endpoints:**
- `GET /` - Health check and API information
- `GET /health` - Health check endpoint
- `POST /slice` - Slice a 3D model file
  - Form data: `uploaded_file` (multipart/form-data)
  - Optional: `printer_def` - Path to printer definition JSON
  - Optional: `settings` - JSON string with custom settings
  - Returns: G-code file as download

**Example API Usage:**
```bash
# Using curl
curl -X POST \
  -F "uploaded_file=@model.stl" \
  http://localhost:3000/slice \
  --output output.gcode

# Using curl with custom settings
curl -X POST \
  -F "uploaded_file=@model.stl" \
  -F "settings={\"infill_line_distance\":0}" \
  http://localhost:3000/slice \
  --output output.gcode
```

### Command-Line Mode

Run CuraEngine directly with command-line arguments:

```bash
docker run --rm curaengine:latest --help
```

Example: Slice a model file:

```bash
docker run --rm \
  -v /path/to/models:/data \
  curaengine:latest \
  slice \
  -j /data/model.json \
  -o /data/output.gcode
```

### Using Docker Compose

1. Create necessary directories:

```bash
mkdir -p data config
```

2. Start the service (API server mode by default):

```bash
docker-compose up -d
```

3. View logs:

```bash
docker-compose logs -f
```

4. Access the API:

The API server will be running at `http://localhost:3000`

5. Stop the service:

```bash
docker-compose down
```

**Note:** To run in CLI mode instead of API mode, modify `docker-compose.yml` and change the `command` to `["--help"]` or your desired CuraEngine command.

### Arcus Communication Mode

CuraEngine supports Arcus socket communication for integration with Cura frontend. To use this mode:

1. Expose the Arcus port (default: 49674):

```bash
docker run -d \
  -p 49674:49674 \
  --name curaengine \
  curaengine:latest
```

2. Connect from Cura or other clients to `localhost:49674`

Note: The exact command-line arguments for Arcus mode may vary. Check CuraEngine documentation for the correct connection syntax.

## Volume Mounts

### Data Directory

Mount a directory for input/output files:

```bash
docker run --rm \
  -v /host/path/to/data:/data \
  curaengine:latest [commands]
```

### Configuration Directory

Mount configuration files (if needed):

```bash
docker run --rm \
  -v /host/path/to/config:/config:ro \
  curaengine:latest [commands]
```

## Environment Variables

The container supports the following environment variables:

- `TZ`: Timezone (default: UTC)
- `PORT`: API server port (default: 3000)
- `RUN_API_SERVER`: Set to "true" to run API server mode (default in docker-compose)

Additional environment variables can be added to `docker-compose.yml` as needed.

## Resource Limits

The `docker-compose.yml` includes default resource limits:
- CPU: 2.0 cores limit, 0.5 cores reservation
- Memory: 4GB limit, 512MB reservation

Adjust these in `docker-compose.yml` based on your server capacity and workload.

## Health Checks

The container includes a basic health check that runs `CuraEngine --help`. This can be customized in `docker-compose.yml`:

```yaml
healthcheck:
  test: ["CMD", "/app/CuraEngine", "--help"]
  interval: 30s
  timeout: 10s
  retries: 3
```

## Security Considerations

- The container runs as a non-root user (UID 1000) for security
- Only necessary runtime libraries are included in the final image
- The image is built using multi-stage builds to minimize attack surface

## Troubleshooting

### Build Fails

1. **Out of memory**: Increase Docker memory limit or use a machine with more RAM
2. **Conan download fails**: 
   - Check internet connection and Conan remote configuration
   - The Docker build uses `conanfile.docker.py` which handles UltiMaker dependencies gracefully
   - If UltiMaker packages are unavailable, they will be built from source with `--build=missing`
   - If you see errors about packages not being found:
     - Ensure `--build=missing` is used (it's included in the Dockerfile)
     - Check that ConanCenter remote is configured (it's added by default)
     - Some packages may need to be built from source if recipes are available
3. **Compiler errors**: Ensure you're using a compatible base image (Ubuntu 22.04)
4. **Package resolution errors**:
   - The Docker conanfile uses fallback mechanisms for UltiMaker packages
   - Packages like `clipper` and `mapbox-wagyu` will be resolved from ConanCenter or built from source
   - If a package cannot be resolved, check if a Conan recipe exists in ConanCenter
   - The build will fail with a clear error message if a required package cannot be found or built

### Runtime Issues

1. **Permission denied**: Check volume mount permissions. The container runs as UID 1000
2. **Library not found**: Most dependencies are statically linked, but if issues occur, check the builder stage logs
3. **Container exits immediately**: Check logs with `docker logs <container-name>`

### Viewing Logs

```bash
# Docker run
docker logs <container-name>

# Docker Compose
docker-compose logs -f
```

## Image Size Optimization

The multi-stage build minimizes the final image size by:
- Only including the compiled executable and essential runtime libraries
- Excluding build tools and dependencies
- Using a minimal Ubuntu base image

Expected final image size: ~200-500MB (depending on dependencies)

## Production Deployment

For production deployment:

1. **Use specific version tags** instead of `latest`
2. **Set up proper logging** (consider using Docker logging drivers)
3. **Configure resource limits** appropriate for your workload
4. **Set up monitoring** for container health
5. **Use secrets management** for any sensitive configuration
6. **Regularly update** the base image and dependencies

## Advanced Usage

### Custom Build Configuration

To modify build options, edit the `Dockerfile` and change the Conan install command:

```dockerfile
RUN conan install . --output-folder=build --build=missing \
    -o enable_arcus=False \  # Disable ARCUS
    -o enable_plugins=False \  # Disable plugins
    ...
```

### Building for Different Architectures

To build for ARM64 or other architectures:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t curaengine:latest .
```

Note: This requires Docker Buildx and may need adjustments to the Dockerfile for cross-compilation.

## Support

For issues related to:
- **CuraEngine functionality**: See [CuraEngine GitHub Issues](https://github.com/Ultimaker/CuraEngine/issues)
- **Docker setup**: Check this documentation or create an issue in the repository

## API Server Features

The Docker image includes a Node.js Express API server that provides:

- **REST API** for slicing 3D models via HTTP
- **File upload** support (multipart/form-data) with 100MB file size limit
- **G-code download** as response
- **Health check endpoints** (`GET /` and `GET /health`) for monitoring
- **Error handling** and comprehensive logging
- **Custom settings** support via JSON parameters

The API server runs on port 3000 by default and can be accessed via:
- Docker Compose: `http://localhost:3000`
- Docker Run: Map port `-p 3000:3000`

**API Usage Example:**
```bash
# Upload and slice a model
curl -X POST \
  -F "uploaded_file=@model.stl" \
  http://localhost:3000/slice \
  --output output.gcode

# With custom settings
curl -X POST \
  -F "uploaded_file=@model.stl" \
  -F 'settings={"infill_line_distance":0,"layer_height":0.2}' \
  http://localhost:3000/slice \
  --output output.gcode
```

## Notes

- The final image is optimized for production use
- All CuraEngine features are enabled (ARCUS, plugins, remote plugins)
- The image includes both CLI and API server modes
- API server mode is recommended for production deployments
- Runtime dependencies are minimized for security and size
- The image runs as a non-root user for security
- **Docker-specific Conan recipe**: Uses `conanfile.docker.py` which handles UltiMaker dependencies gracefully without patching
- **No fragile patching**: The build system no longer relies on patching `conanfile.py`, making it more robust and maintainable

## License

CuraEngine is released under the AGPLv3 license. See the [LICENSE](LICENSE) file for details.

