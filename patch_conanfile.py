#!/usr/bin/env python3
"""
Patch conanfile.py to remove dependency on UltiMaker python_requires
when the UltiMaker Conan remote is unreachable.
Uses a line-by-line approach to maintain valid Python syntax.
"""
import sys

def patch_conanfile(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        original_line = line
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())
        
        # Handle python_requires line
        if 'python_requires = "sentrylibrary/1.0.0"' in line:
            new_lines.append(' ' * indent + '# python_requires commented out for Docker build (UltiMaker remote unreachable)\n')
            new_lines.append(' ' * indent + '# python_requires = "sentrylibrary/1.0.0", "npmpackage/[>=1.0.0]"\n')
            i += 1
            continue
        
        # Handle python_requires_extend line
        if 'python_requires_extend = "sentrylibrary.SentryLibrary"' in line:
            new_lines.append(' ' * indent + '# python_requires_extend commented out\n')
            new_lines.append(' ' * indent + '# python_requires_extend = "sentrylibrary.SentryLibrary"\n')
            i += 1
            continue
        
        # Handle all super() calls - these must be commented out since we removed python_requires_extend
        # Check these early to catch them before other handlers
        if 'super().config_options()' in stripped:
            new_lines.append(' ' * indent + '# super().config_options()  # Disabled (no parent class after removing python_requires_extend)\n')
            i += 1
            continue
        
        if 'super().configure()' in stripped:
            new_lines.append(' ' * indent + '# super().configure()  # Disabled (no parent class after removing python_requires_extend)\n')
            i += 1
            continue
        
        if 'super().validate()' in stripped:
            new_lines.append(' ' * indent + '# super().validate()  # Disabled (no parent class after removing python_requires_extend)\n')
            i += 1
            continue
        
        if 'super().requirements()' in stripped:
            new_lines.append(' ' * indent + '# super().requirements()  # Disabled (no parent class after removing python_requires_extend)\n')
            i += 1
            continue
        
        # Catch-all for any other super() calls (safety net)
        if stripped.startswith('super().') and stripped.endswith('()'):
            new_lines.append(' ' * indent + '# ' + stripped + '  # Disabled (no parent class after removing python_requires_extend)\n')
            i += 1
            continue
        
        # Handle init() method
        if 'def init(self):' in line:
            new_lines.append(line)
            i += 1
            # Skip and comment out the next two lines (the body)
            if i < len(lines) and 'python_requires["sentrylibrary"]' in lines[i]:
                new_lines.append(' ' * indent + '    # Sentry support disabled for Docker build (UltiMaker remote unreachable)\n')
                new_lines.append(' ' * indent + '    # ' + lines[i].lstrip())
                i += 1
            if i < len(lines) and 'self.options.update' in lines[i]:
                new_lines.append(' ' * indent + '    # ' + lines[i].lstrip())
                i += 1
            # Add pass statement
            new_lines.append(' ' * indent + '    pass\n')
            continue
        
        # Handle setup_cmake_toolchain_sentry
        if 'self.setup_cmake_toolchain_sentry(tc)' in line:
            new_lines.append(' ' * indent + '# self.setup_cmake_toolchain_sentry(tc)  # Disabled (UltiMaker remote unreachable)\n')
            i += 1
            continue
        
        # Handle send_sentry_debug_files
        if 'self.send_sentry_debug_files(binary_basename="CuraEngine")' in line:
            new_lines.append(' ' * indent + '# self.send_sentry_debug_files(binary_basename="CuraEngine")  # Disabled (UltiMaker remote unreachable)\n')
            i += 1
            continue
        
        # Handle npmpackage in Emscripten if block
        if 'if self.settings.os == "Emscripten":' in line:
            new_lines.append(line)
            i += 1
            # Check if next line is the npmpackage line
            if i < len(lines) and 'python_requires["npmpackage"]' in lines[i]:
                # Comment it out and add pass
                new_lines.append(' ' * indent + '    # self.python_requires["npmpackage"].module.conf_package_json(self)  # Disabled (UltiMaker remote unreachable)\n')
                new_lines.append(' ' * indent + '    pass\n')
                i += 1
            else:
                # Always add pass even if npmpackage line not found (prevents empty if block)
                new_lines.append(' ' * indent + '    pass  # npmpackage disabled (UltiMaker remote unreachable)\n')
            continue
        
        # Handle npmpackage line if not in Emscripten block (shouldn't happen, but just in case)
        if 'python_requires["npmpackage"]' in line:
            new_lines.append(' ' * indent + '# ' + line.lstrip())
            i += 1
            continue
        
        # Handle UltiMaker package dependencies in requirements() method
        # Remove @ultimaker reference to try ConanCenter or build from source
        if 'for req in self.conan_data["requirements"]:' in line:
            new_lines.append(line)
            i += 1
            # Add logic to remove @ultimaker reference before the onetbb check
            # Code inside the loop should be indented by indent + 4 (one level deeper)
            loop_indent = indent + 4
            if i < len(lines):
                next_line = lines[i] if i < len(lines) else ''
                # Insert logic to remove @ultimaker reference (at loop body indent level)
                new_lines.append(' ' * loop_indent + '# Remove @ultimaker reference (remote unreachable, try ConanCenter or build from source)\n')
                new_lines.append(' ' * loop_indent + 'if "@ultimaker" in req:\n')
                new_lines.append(' ' * (loop_indent + 4) + 'req = req.split("@")[0]  # Remove @ultimaker reference\n')
                new_lines.append(' ' * (loop_indent + 4) + 'print(f"Trying package without UltiMaker reference: {req}")\n')
                # Now add the next line (comment or onetbb check) - preserve its original indentation
                new_lines.append(next_line)
                i += 1
                continue
        
        # Handle UltiMaker packages in other loops (arcus, scripta from conandata.yml)
        if 'for req in self.conan_data["requirements_arcus"]:' in line or \
           'for req in self.conan_data["requirements_plugins"]:' in line or \
           'for req in self.conan_data["requirements_cura_resources"]:' in line:
            new_lines.append(line)
            i += 1
            # Add logic to remove @ultimaker reference
            # Code inside the loop should be indented by indent + 4 (one level deeper)
            loop_indent = indent + 4
            if i < len(lines):
                next_line = lines[i] if i < len(lines) else ''
                new_lines.append(' ' * loop_indent + '# Remove @ultimaker reference (remote unreachable, try ConanCenter or build from source)\n')
                new_lines.append(' ' * loop_indent + 'if "@ultimaker" in req:\n')
                new_lines.append(' ' * (loop_indent + 4) + 'req = req.split("@")[0]  # Remove @ultimaker reference\n')
                new_lines.append(' ' * (loop_indent + 4) + 'print(f"Trying package without UltiMaker reference: {req}")\n')
                new_lines.append(next_line)
                i += 1
                continue
        
        # Handle hardcoded UltiMaker package dependencies
        # clipper/6.4.2@ultimaker/stable -> remove @ultimaker reference
        if '@ultimaker/stable' in line and 'clipper' in line and 'self.requires' in line:
            # Extract version and try without @ultimaker
            new_lines.append(' ' * indent + '# ' + line.lstrip() + '  # UltiMaker remote unreachable\n')
            new_lines.append(' ' * indent + '    # Try without @ultimaker reference (ConanCenter or build from source):\n')
            new_lines.append(' ' * indent + '    self.requires("clipper/6.4.2")  # Removed @ultimaker/stable\n')
            i += 1
            continue
        
        # mapbox-wagyu/0.5.0@ultimaker/stable -> remove @ultimaker reference
        if '@ultimaker/stable' in line and 'mapbox-wagyu' in line and 'self.requires' in line:
            new_lines.append(' ' * indent + '# ' + line.lstrip() + '  # UltiMaker remote unreachable\n')
            new_lines.append(' ' * indent + '    # Try without @ultimaker reference (ConanCenter or build from source):\n')
            new_lines.append(' ' * indent + '    self.requires("mapbox-wagyu/0.5.0")  # Removed @ultimaker/stable\n')
            i += 1
            continue
        
        # Default: keep the line as-is
        new_lines.append(line)
        i += 1
    
    # Write the patched file
    with open(filename, 'w') as f:
        f.writelines(new_lines)
    
    # Verify the patch
    content = ''.join(new_lines)
    if '# python_requires' in content:
        print(f"Successfully patched {filename}")
        print("  - python_requires commented out")
        if '# python_requires_extend' in content:
            print("  - python_requires_extend commented out")
        if 'def init(self):' in content and 'pass' in content:
            print("  - init() method patched with pass statement")
        if 'if self.settings.os == "Emscripten":' in content:
            print("  - Emscripten if block patched")
    else:
        print(f"WARNING: Patch may not have worked correctly for {filename}")
        sys.exit(1)
    
    # Verify Python syntax
    try:
        compile(content, filename, 'exec')
        print("  - Python syntax verified")
    except SyntaxError as e:
        print(f"ERROR: Patched file has syntax errors: {e}")
        print(f"  Line {e.lineno}: {e.text}")
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: patch_conanfile.py <conanfile.py>")
        sys.exit(1)
    
    patch_conanfile(sys.argv[1])