const { execSync } = require("child_process");
const { dirname } = require("path");
const appDir = dirname(require.main.filename);
const filePath = `${appDir}/uploads`;

/**
 * Slice a 3D model file using CuraEngine
 * @param {string} input_file - Name of the uploaded file
 * @param {string} printer_def - Path to printer definition JSON file (optional)
 * @param {object} options - Additional slicing options
 * @returns {string} Path to the generated G-code file
 */
const sliceModel = (
  input_file,
  printer_def = null,
  options = {}
) => {
  console.log(`Starting slice for file: ${input_file}`);
  
  const outputPath = `${appDir}/outputs/${input_file.split(".")[0]}.gcode`;
  const inputPath = `${filePath}/${input_file}`;
  
  // Build CuraEngine command (use full path to executable)
  let command = `/app/CuraEngine slice -v`;
  
  // Add printer definition if provided
  if (printer_def) {
    command += ` -j ${printer_def}`;
  }
  
  // Add custom settings from options
  if (options.settings) {
    for (const [key, value] of Object.entries(options.settings)) {
      command += ` -s ${key}=${value}`;
    }
  }
  
  // Add output file
  command += ` -o ${outputPath}`;
  
  // Add input file
  command += ` -l ${inputPath}`;
  
  try {
    console.log(`Executing: ${command}`);
    const output = execSync(command, { 
      encoding: "utf-8",
      maxBuffer: 10 * 1024 * 1024 // 10MB buffer
    });
    
    console.log("Slice completed successfully");
    console.log("Output was:\n", output);
    
    return outputPath;
  } catch (error) {
    console.error("Error during slicing:", error.message);
    if (error.stdout) console.error("STDOUT:", error.stdout);
    if (error.stderr) console.error("STDERR:", error.stderr);
    throw error;
  }
};

module.exports = { sliceModel };

