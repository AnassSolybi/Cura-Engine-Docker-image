const express = require("express");
const multer = require("multer");
const { sliceModel } = require("./slice");
const path = require("path");
const fs = require("fs");
require("dotenv").config();

const app = express();
const { dirname } = require("path");
const appDir = dirname(require.main.filename);

// Ensure uploads and outputs directories exist
const uploadsDir = `${appDir}/uploads`;
const outputsDir = `${appDir}/outputs`;

[uploadsDir, outputsDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    console.log(`Created directory: ${dir}`);
  }
});

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: false, limit: "50mb" }));

const PORT = process.env.PORT || 3000;

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    // Preserve original filename with timestamp prefix
    const timestamp = Date.now();
    const originalName = file.originalname || "uploaded_file";
    cb(null, `${timestamp}-${originalName}`);
  },
});

const upload = multer({ 
  storage: storage,
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB limit
  }
});

// Health check endpoint
app.get("/", (req, res) => {
  res.json({
    status: "ok",
    service: "CuraEngine API",
    version: "1.0.0",
    endpoints: {
      health: "GET /",
      slice: "POST /slice"
    }
  });
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "healthy" });
});

// Slice endpoint - accepts STL file and returns G-code
app.post("/slice", upload.single("uploaded_file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ 
        error: "No file uploaded",
        message: "Please upload a file using the 'uploaded_file' field"
      });
    }

    console.log(`Received file: ${req.file.filename} (${req.file.size} bytes)`);
    
    // Get optional parameters from request
    const printerDef = req.body.printer_def || null;
    const settings = req.body.settings ? JSON.parse(req.body.settings) : {};
    
    // Perform slicing
    const outputPath = sliceModel(req.file.filename, printerDef, { settings });
    
    // Check if output file exists
    if (!fs.existsSync(outputPath)) {
      return res.status(500).json({ 
        error: "Slicing failed",
        message: "G-code file was not generated"
      });
    }
    
    // Send the G-code file as download
    const outputFilename = path.basename(outputPath);
    res.download(outputPath, outputFilename, (err) => {
      if (err) {
        console.error("Error sending file:", err);
        if (!res.headersSent) {
          res.status(500).json({ error: "Error sending file" });
        }
      } else {
        console.log(`File sent: ${outputFilename}`);
        // Clean up files after sending (optional)
        // fs.unlinkSync(req.file.path);
        // fs.unlinkSync(outputPath);
      }
    });
  } catch (error) {
    console.error("Error in /slice endpoint:", error);
    res.status(500).json({ 
      error: "Slicing failed",
      message: error.message 
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ 
        error: "File too large",
        message: "File size exceeds 100MB limit"
      });
    }
  }
  console.error("Unhandled error:", err);
  res.status(500).json({ 
    error: "Internal server error",
    message: err.message 
  });
});

app.listen(PORT, () => {
  console.log(`CuraEngine API server running on port ${PORT}`);
  console.log(`Uploads directory: ${uploadsDir}`);
  console.log(`Outputs directory: ${outputsDir}`);
});

