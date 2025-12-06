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
        
        # Handle super().config_options() and super().configure() calls
        # These must be commented out since we removed python_requires_extend
        # Check these early to catch them before other handlers
        if 'super().config_options()' in stripped:
            new_lines.append(' ' * indent + '# super().config_options()  # Disabled (no parent class after removing python_requires_extend)\n')
            i += 1
            continue
        
        if 'super().configure()' in stripped:
            new_lines.append(' ' * indent + '# super().configure()  # Disabled (no parent class after removing python_requires_extend)\n')
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