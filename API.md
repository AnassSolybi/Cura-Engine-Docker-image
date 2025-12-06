# CuraEngine HTTP REST API Documentation

## Table of Contents

1. [Introduction](#introduction)
2. [Base URL and Versioning](#base-url-and-versioning)
3. [Authentication](#authentication)
4. [Endpoints](#endpoints)
   - [GET /](#get-)
   - [GET /health](#get-health)
   - [POST /slice](#post-slice)
5. [Request/Response Examples](#requestresponse-examples)
6. [Parameters Reference](#parameters-reference)
7. [Error Handling](#error-handling)
8. [Integration Guide](#integration-guide)

---

## Introduction

The CuraEngine HTTP REST API provides a web-based interface for slicing 3D models into G-code instructions for 3D printers. This API allows you to upload STL files and receive generated G-code files via HTTP requests, making it easy to integrate 3D printing capabilities into web applications, mobile apps, or automated workflows.

### What the API Does

- Accepts 3D model files (STL format) via HTTP POST requests
- Processes models using CuraEngine's slicing engine
- Returns generated G-code files for 3D printing
- Supports custom slicing settings and printer definitions
- Provides health check endpoints for monitoring

### Key Features

- **File Upload**: Multipart form-data file uploads up to 100MB
- **Custom Settings**: Override default slicing parameters via JSON
- **Printer Definitions**: Specify printer configurations via JSON definition files
- **Health Monitoring**: Built-in health check endpoints
- **Error Handling**: Comprehensive error responses with detailed messages

---

## Base URL and Versioning

### Base URL

The API server runs on port **3000** by default. The base URL depends on your deployment:

- **Local Development**: `http://localhost:3000`
- **Docker Container**: `http://localhost:3000` (when port is mapped)
- **Production**: `https://your-domain.com` (configure as needed)

### Versioning

Current API version: **1.0.0**

The API version is included in the response from the root endpoint (`GET /`). Future versions may introduce breaking changes, which will be documented in release notes.

### Port Configuration

The API server port can be configured using the `PORT` environment variable:

```bash
PORT=8080 node server.js
```

Or via Docker:

```bash
docker run -p 8080:8080 -e PORT=8080 curaengine:latest api
```

---

## Authentication

Currently, the API does not require authentication. All endpoints are publicly accessible. For production deployments, consider:

- Implementing API key authentication
- Using reverse proxy with authentication (e.g., nginx, Traefik)
- Network-level security (firewall rules, VPN access)
- Rate limiting to prevent abuse

---

## Endpoints

### GET /

Returns API information and available endpoints.

#### Request

```http
GET / HTTP/1.1
Host: localhost:3000
```

#### Response

**Status Code:** `200 OK`

**Content-Type:** `application/json`

**Response Body:**

```json
{
  "status": "ok",
  "service": "CuraEngine API",
  "version": "1.0.0",
  "endpoints": {
    "health": "GET /",
    "slice": "POST /slice"
  }
}
```

#### Example

```bash
curl http://localhost:3000/
```

---

### GET /health

Simple health check endpoint for monitoring and load balancers.

#### Request

```http
GET /health HTTP/1.1
Host: localhost:3000
```

#### Response

**Status Code:** `200 OK`

**Content-Type:** `application/json`

**Response Body:**

```json
{
  "status": "healthy"
}
```

#### Example

```bash
curl http://localhost:3000/health
```

**Use Cases:**

- Health checks for container orchestration (Kubernetes, Docker Swarm)
- Load balancer health probes
- Monitoring system integration
- Service discovery

---

### POST /slice

Slices a 3D model file (STL format) and returns the generated G-code file.

#### Request

**Method:** `POST`

**Content-Type:** `multipart/form-data`

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `uploaded_file` | File | The STL file to slice (required) |

**Optional Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `printer_def` | String | Path to printer definition JSON file (e.g., `/printer-settings/ultimaker3.def.json`) |
| `settings` | String | JSON string containing custom slicing settings (see [Settings Format](#settings-format)) |

**File Size Limit:** 100MB

#### Response

**Success Response:**

**Status Code:** `200 OK`

**Content-Type:** `application/octet-stream` or `text/plain`

**Headers:**
- `Content-Disposition: attachment; filename="<output_filename>.gcode"`

**Response Body:** Binary G-code file content

**Error Responses:**

See [Error Handling](#error-handling) section for detailed error response formats.

#### Settings Format

The `settings` parameter accepts a JSON string with key-value pairs. Each key represents a CuraEngine setting, and the value is the setting's value.

**Example Settings JSON:**

```json
{
  "infill_line_distance": 0,
  "layer_height": 0.2,
  "wall_line_count": 3,
  "infill_sparse_density": 20,
  "support_enable": true
}
```

**Common Settings:**

- `layer_height`: Layer height in millimeters (e.g., `0.2`)
- `wall_line_count`: Number of wall lines (e.g., `3`)
- `infill_sparse_density`: Infill density percentage (e.g., `20`)
- `infill_line_distance`: Distance between infill lines (e.g., `0` for solid)
- `support_enable`: Enable support structures (`true`/`false`)
- `adhesion_type`: Type of bed adhesion (`skirt`, `brim`, `raft`, `none`)

For a complete list of available settings, refer to CuraEngine's settings documentation or printer definition files.

#### Examples

**Basic Slice Request:**

```bash
curl -X POST \
  -F "uploaded_file=@model.stl" \
  http://localhost:3000/slice \
  --output output.gcode
```

**With Custom Settings:**

```bash
curl -X POST \
  -F "uploaded_file=@model.stl" \
  -F 'settings={"layer_height":0.2,"infill_sparse_density":20,"wall_line_count":3}' \
  http://localhost:3000/slice \
  --output output.gcode
```

**With Printer Definition:**

```bash
curl -X POST \
  -F "uploaded_file=@model.stl" \
  -F "printer_def=/printer-settings/ultimaker3.def.json" \
  -F 'settings={"layer_height":0.15}' \
  http://localhost:3000/slice \
  --output output.gcode
```

---

## Request/Response Examples

### cURL Examples

#### Basic Slice Request

```bash
curl -X POST \
  -F "uploaded_file=@/path/to/model.stl" \
  http://localhost:3000/slice \
  --output /path/to/output.gcode
```

#### Slice with Custom Settings

```bash
curl -X POST \
  -F "uploaded_file=@model.stl" \
  -F 'settings={"layer_height":0.2,"infill_sparse_density":30,"support_enable":true}' \
  http://localhost:3000/slice \
  --output output.gcode
```

#### Slice with Printer Definition

```bash
curl -X POST \
  -F "uploaded_file=@model.stl" \
  -F "printer_def=/printer-settings/ultimaker3.def.json" \
  http://localhost:3000/slice \
  --output output.gcode
```

#### Check API Health

```bash
curl http://localhost:3000/health
```

### JavaScript/Fetch Examples

#### Basic Slice Request

```javascript
const formData = new FormData();
formData.append('uploaded_file', fileInput.files[0]);

fetch('http://localhost:3000/slice', {
  method: 'POST',
  body: formData
})
  .then(response => {
    if (!response.ok) {
      return response.json().then(err => Promise.reject(err));
    }
    return response.blob();
  })
  .then(blob => {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'output.gcode';
    a.click();
  })
  .catch(error => {
    console.error('Error:', error);
  });
```

#### Slice with Custom Settings

```javascript
const formData = new FormData();
formData.append('uploaded_file', fileInput.files[0]);

const settings = {
  layer_height: 0.2,
  infill_sparse_density: 30,
  support_enable: true
};
formData.append('settings', JSON.stringify(settings));

fetch('http://localhost:3000/slice', {
  method: 'POST',
  body: formData
})
  .then(response => response.blob())
  .then(blob => {
    // Handle G-code file download
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'output.gcode';
    a.click();
  })
  .catch(error => {
    console.error('Error:', error);
  });
```

#### Error Handling Example

```javascript
async function sliceModel(file, settings = {}) {
  const formData = new FormData();
  formData.append('uploaded_file', file);
  
  if (Object.keys(settings).length > 0) {
    formData.append('settings', JSON.stringify(settings));
  }

  try {
    const response = await fetch('http://localhost:3000/slice', {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || error.error);
    }

    const blob = await response.blob();
    return blob;
  } catch (error) {
    console.error('Slicing failed:', error);
    throw error;
  }
}

// Usage
sliceModel(fileInput.files[0], {
  layer_height: 0.2,
  infill_sparse_density: 20
})
  .then(blob => {
    // Download the G-code file
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'output.gcode';
    a.click();
  })
  .catch(error => {
    alert('Slicing failed: ' + error.message);
  });
```

### Python Examples

#### Basic Slice Request

```python
import requests

url = 'http://localhost:3000/slice'

with open('model.stl', 'rb') as f:
    files = {'uploaded_file': f}
    response = requests.post(url, files=files)

if response.status_code == 200:
    with open('output.gcode', 'wb') as f:
        f.write(response.content)
    print('G-code saved to output.gcode')
else:
    print(f'Error: {response.status_code}')
    print(response.json())
```

#### Slice with Custom Settings

```python
import requests
import json

url = 'http://localhost:3000/slice'

settings = {
    'layer_height': 0.2,
    'infill_sparse_density': 30,
    'support_enable': True
}

with open('model.stl', 'rb') as f:
    files = {'uploaded_file': f}
    data = {
        'settings': json.dumps(settings)
    }
    response = requests.post(url, files=files, data=data)

if response.status_code == 200:
    with open('output.gcode', 'wb') as f:
        f.write(response.content)
    print('G-code saved successfully')
else:
    error = response.json()
    print(f'Error: {error.get("error", "Unknown error")}')
    print(f'Message: {error.get("message", "")}')
```

#### Error Handling Example

```python
import requests
import json
import sys

def slice_model(file_path, settings=None, printer_def=None):
    url = 'http://localhost:3000/slice'
    
    files = {'uploaded_file': open(file_path, 'rb')}
    data = {}
    
    if settings:
        data['settings'] = json.dumps(settings)
    
    if printer_def:
        data['printer_def'] = printer_def
    
    try:
        response = requests.post(url, files=files, data=data)
        files['uploaded_file'].close()
        
        if response.status_code == 200:
            return response.content
        else:
            error = response.json()
            raise Exception(f"{error.get('error', 'Unknown error')}: {error.get('message', '')}")
    except requests.exceptions.RequestException as e:
        raise Exception(f"Request failed: {str(e)}")

# Usage
try:
    settings = {
        'layer_height': 0.2,
        'infill_sparse_density': 20
    }
    gcode = slice_model('model.stl', settings=settings)
    
    with open('output.gcode', 'wb') as f:
        f.write(gcode)
    print('Slicing completed successfully')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
```

### Node.js/Express Example

```javascript
const express = require('express');
const multer = require('multer');
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

const app = express();
const upload = multer({ dest: 'uploads/' });

app.post('/proxy-slice', upload.single('model'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const formData = new FormData();
    formData.append('uploaded_file', fs.createReadStream(req.file.path));
    
    if (req.body.settings) {
      formData.append('settings', req.body.settings);
    }

    const response = await axios.post('http://localhost:3000/slice', formData, {
      headers: formData.getHeaders(),
      responseType: 'stream'
    });

    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Disposition', 'attachment; filename="output.gcode"');
    
    response.data.pipe(res);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ 
      error: 'Slicing failed', 
      message: error.message 
    });
  }
});

app.listen(3001, () => {
  console.log('Proxy server running on port 3001');
});
```

---

## Parameters Reference

### uploaded_file

**Type:** File (multipart/form-data)

**Required:** Yes

**Description:** The 3D model file to slice. Currently supports STL format.

**File Size Limit:** 100MB

**Example:**
```bash
-F "uploaded_file=@model.stl"
```

### printer_def

**Type:** String

**Required:** No

**Description:** Path to a printer definition JSON file. This file contains printer-specific settings and configurations. The path should be accessible from within the CuraEngine container.

**Example:**
```bash
-F "printer_def=/printer-settings/ultimaker3.def.json"
```

**Note:** The printer definition file must exist in the container's filesystem. If using Docker, you may need to mount the directory containing printer definitions.

### settings

**Type:** String (JSON)

**Required:** No

**Description:** JSON string containing custom slicing settings. Each key represents a CuraEngine setting name, and the value is the setting's value.

**Format:**
```json
{
  "setting_key": "value",
  "another_setting": 123
}
```

**Example:**
```bash
-F 'settings={"layer_height":0.2,"infill_sparse_density":20}'
```

**Common Settings:**

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `layer_height` | Number | Layer height in millimeters | `0.2` |
| `wall_line_count` | Integer | Number of wall lines | `3` |
| `infill_sparse_density` | Number | Infill density percentage (0-100) | `20` |
| `infill_line_distance` | Number | Distance between infill lines | `0` (solid) |
| `support_enable` | Boolean | Enable support structures | `true` |
| `adhesion_type` | String | Bed adhesion type | `"brim"` |
| `print_temperature` | Number | Printing temperature in Celsius | `210` |
| `bed_temperature` | Number | Bed temperature in Celsius | `60` |

**Note:** For a complete list of available settings, refer to CuraEngine's settings documentation or examine printer definition files.

---

## Error Handling

### Error Response Format

All error responses follow a consistent JSON format:

```json
{
  "error": "Error Type",
  "message": "Detailed error message"
}
```

### HTTP Status Codes

| Status Code | Description | When It Occurs |
|-------------|-------------|----------------|
| `200 OK` | Success | Request completed successfully |
| `400 Bad Request` | Client Error | Invalid request parameters or missing required fields |
| `500 Internal Server Error` | Server Error | Slicing failed or server encountered an error |

### Common Error Responses

#### No File Uploaded

**Status Code:** `400 Bad Request`

**Response:**
```json
{
  "error": "No file uploaded",
  "message": "Please upload a file using the 'uploaded_file' field"
}
```

**Cause:** The `uploaded_file` parameter is missing from the request.

**Solution:** Ensure you're sending the file with the correct field name `uploaded_file`.

#### File Too Large

**Status Code:** `400 Bad Request`

**Response:**
```json
{
  "error": "File too large",
  "message": "File size exceeds 100MB limit"
}
```

**Cause:** The uploaded file exceeds the 100MB size limit.

**Solution:** Compress or reduce the size of your STL file, or increase the file size limit in the server configuration.

#### Slicing Failed

**Status Code:** `500 Internal Server Error`

**Response:**
```json
{
  "error": "Slicing failed",
  "message": "G-code file was not generated"
}
```

**Cause:** CuraEngine failed to generate G-code. This could be due to:
- Invalid STL file format
- Corrupted model file
- Invalid settings
- Printer definition file not found
- Insufficient system resources

**Solution:**
- Verify the STL file is valid and not corrupted
- Check that settings are valid
- Ensure printer definition path is correct (if provided)
- Check server logs for detailed error messages

#### Internal Server Error

**Status Code:** `500 Internal Server Error`

**Response:**
```json
{
  "error": "Internal server error",
  "message": "Error message from server"
}
```

**Cause:** An unexpected error occurred on the server.

**Solution:** Check server logs for detailed error information. This may indicate a configuration issue or server problem.

### Error Handling Best Practices

1. **Always Check Status Codes:** Verify the HTTP status code before processing the response.

2. **Parse Error Responses:** When status code is not 200, parse the JSON error response to get detailed information.

3. **Handle Network Errors:** Implement retry logic for network failures.

4. **Validate Files Before Upload:** Check file size and format on the client side before uploading.

5. **Log Errors:** Log error responses for debugging and monitoring.

**Example Error Handling:**

```javascript
async function sliceModel(file) {
  const formData = new FormData();
  formData.append('uploaded_file', file);

  try {
    const response = await fetch('http://localhost:3000/slice', {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(`${error.error}: ${error.message}`);
    }

    return await response.blob();
  } catch (error) {
    if (error.name === 'TypeError') {
      throw new Error('Network error: Could not connect to server');
    }
    throw error;
  }
}
```

### Troubleshooting Guide

#### Problem: "No file uploaded" error

**Possible Causes:**
- Incorrect form field name (should be `uploaded_file`)
- File not included in the request
- Content-Type header not set correctly

**Solutions:**
- Verify the form field name matches `uploaded_file`
- Check that the file is actually being sent in the request
- Ensure `Content-Type: multipart/form-data` is set (usually automatic)

#### Problem: "File too large" error

**Possible Causes:**
- File exceeds 100MB limit
- Server configuration has lower limit

**Solutions:**
- Reduce file size by simplifying the model
- Use file compression
- Modify server configuration to increase limit (edit `server.js`)

#### Problem: "Slicing failed" error

**Possible Causes:**
- Invalid or corrupted STL file
- Invalid settings format
- Printer definition file not found
- CuraEngine execution error

**Solutions:**
- Validate STL file format
- Check settings JSON syntax
- Verify printer definition path exists in container
- Check server logs for CuraEngine error messages
- Try with default settings first

#### Problem: Slow response times

**Possible Causes:**
- Large model files
- Complex geometry
- Server resource constraints
- Network latency

**Solutions:**
- Optimize model geometry
- Use appropriate layer height and infill settings
- Increase server resources (CPU, RAM)
- Consider async processing for large files

---

## Integration Guide

### Quick Start

1. **Start the API Server**

   Using Docker:
   ```bash
   docker run -d -p 3000:3000 --name curaengine-api curaengine:latest api
   ```

   Or using Docker Compose:
   ```bash
   docker-compose up -d
   ```

2. **Test the API**

   ```bash
   curl http://localhost:3000/health
   ```

3. **Slice Your First Model**

   ```bash
   curl -X POST \
     -F "uploaded_file=@model.stl" \
     http://localhost:3000/slice \
     --output output.gcode
   ```

### Best Practices

#### 1. File Validation

Always validate files on the client side before uploading:

```javascript
function validateFile(file) {
  // Check file type
  if (!file.name.endsWith('.stl')) {
    throw new Error('Only STL files are supported');
  }
  
  // Check file size (100MB limit)
  const maxSize = 100 * 1024 * 1024; // 100MB
  if (file.size > maxSize) {
    throw new Error('File size exceeds 100MB limit');
  }
  
  return true;
}
```

#### 2. Settings Validation

Validate settings before sending:

```javascript
function validateSettings(settings) {
  const validSettings = {};
  
  // Validate layer_height
  if (settings.layer_height !== undefined) {
    const height = parseFloat(settings.layer_height);
    if (isNaN(height) || height <= 0 || height > 1) {
      throw new Error('layer_height must be between 0 and 1');
    }
    validSettings.layer_height = height;
  }
  
  // Validate infill_sparse_density
  if (settings.infill_sparse_density !== undefined) {
    const density = parseFloat(settings.infill_sparse_density);
    if (isNaN(density) || density < 0 || density > 100) {
      throw new Error('infill_sparse_density must be between 0 and 100');
    }
    validSettings.infill_sparse_density = density;
  }
  
  return validSettings;
}
```

#### 3. Progress Indication

For large files, implement progress indication:

```javascript
function sliceModelWithProgress(file, settings, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const formData = new FormData();
    
    formData.append('uploaded_file', file);
    if (settings) {
      formData.append('settings', JSON.stringify(settings));
    }
    
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) {
        const percentComplete = (e.loaded / e.total) * 100;
        onProgress(percentComplete);
      }
    });
    
    xhr.addEventListener('load', () => {
      if (xhr.status === 200) {
        resolve(xhr.response);
      } else {
        reject(new Error(`Request failed: ${xhr.statusText}`));
      }
    });
    
    xhr.addEventListener('error', () => {
      reject(new Error('Network error'));
    });
    
    xhr.open('POST', 'http://localhost:3000/slice');
    xhr.responseType = 'blob';
    xhr.send(formData);
  });
}
```

#### 4. Error Recovery

Implement retry logic for transient errors:

```javascript
async function sliceModelWithRetry(file, settings, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await sliceModel(file, settings);
    } catch (error) {
      if (i === maxRetries - 1) {
        throw error;
      }
      
      // Wait before retrying (exponential backoff)
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, i) * 1000));
    }
  }
}
```

#### 5. Timeout Handling

Set appropriate timeouts for requests:

```javascript
async function sliceModelWithTimeout(file, settings, timeout = 300000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);
  
  try {
    const formData = new FormData();
    formData.append('uploaded_file', file);
    if (settings) {
      formData.append('settings', JSON.stringify(settings));
    }
    
    const response = await fetch('http://localhost:3000/slice', {
      method: 'POST',
      body: formData,
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message);
    }
    
    return await response.blob();
  } catch (error) {
    clearTimeout(timeoutId);
    if (error.name === 'AbortError') {
      throw new Error('Request timeout');
    }
    throw error;
  }
}
```

### File Size Limits

- **Maximum File Size:** 100MB
- **Recommended File Size:** < 50MB for optimal performance
- **Large Files:** Consider preprocessing or simplifying models before uploading

### Performance Considerations

1. **Model Complexity:** Complex models with many triangles take longer to slice
2. **Settings Impact:** Certain settings (e.g., high infill density, support structures) increase processing time
3. **Server Resources:** Ensure adequate CPU and RAM for concurrent requests
4. **Network Bandwidth:** Large G-code files may take time to download

### Rate Limiting

Currently, the API does not implement rate limiting. For production deployments, consider:

- Implementing rate limiting middleware (e.g., `express-rate-limit`)
- Using reverse proxy with rate limiting (e.g., nginx, Traefik)
- Monitoring API usage and implementing quotas

**Example Rate Limiting:**

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/slice', limiter);
```

### Security Considerations

1. **File Validation:** Validate file types and sizes on the server
2. **Input Sanitization:** Sanitize all user inputs, especially settings JSON
3. **Resource Limits:** Set appropriate timeouts and resource limits
4. **Error Messages:** Avoid exposing sensitive information in error messages
5. **HTTPS:** Use HTTPS in production to encrypt data in transit
6. **Authentication:** Implement authentication for production deployments

### Monitoring

Monitor the API for:

- Response times
- Error rates
- File upload sizes
- Slicing success/failure rates
- Server resource usage

**Example Health Check Script:**

```bash
#!/bin/bash
while true; do
  response=$(curl -s http://localhost:3000/health)
  if [ "$response" != '{"status":"healthy"}' ]; then
    echo "API health check failed: $response"
    # Send alert
  fi
  sleep 60
done
```

### Production Deployment Checklist

- [ ] Configure HTTPS/TLS
- [ ] Set up authentication/authorization
- [ ] Implement rate limiting
- [ ] Configure logging and monitoring
- [ ] Set up error tracking
- [ ] Configure resource limits
- [ ] Set up backup and recovery
- [ ] Document custom settings and printer definitions
- [ ] Test with production workloads
- [ ] Set up health check monitoring

---

## Additional Resources

- **CuraEngine GitHub:** https://github.com/Ultimaker/CuraEngine
- **CuraEngine Documentation:** See project README and wiki
- **Docker Deployment Guide:** See `DOCKER.md` in this repository
- **Cura Settings Documentation:** https://github.com/Ultimaker/Cura/wiki

---

## Support

For issues, questions, or contributions:

- **GitHub Issues:** https://github.com/Ultimaker/CuraEngine/issues
- **Documentation:** Check this file and `DOCKER.md` for deployment information

---

## License

CuraEngine is released under the AGPLv3 license. See the [LICENSE](LICENSE) file for details.

