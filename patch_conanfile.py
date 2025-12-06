#!/usr/bin/env python3
"""
Patch conanfile.py to remove dependency on UltiMaker python_requires
when the UltiMaker Conan remote is unreachable.
"""
import sys
import re

def patch_conanfile(filename):
    with open(filename, 'r') as f:
        content = f.read()
    
    # Comment out python_requires line
    content = re.sub(
        r'^(\s*)python_requires = "sentrylibrary/1.0.0", "npmpackage/\[>=1.0.0\]"',
        r'\1# python_requires commented out for Docker build (UltiMaker remote unreachable)\n\1# python_requires = "sentrylibrary/1.0.0", "npmpackage/[>=1.0.0]"',
        content,
        flags=re.MULTILINE
    )
    
    # Comment out python_requires_extend line
    content = re.sub(
        r'^(\s*)python_requires_extend = "sentrylibrary.SentryLibrary"',
        r'\1# python_requires_extend commented out\n\1# python_requires_extend = "sentrylibrary.SentryLibrary"',
        content,
        flags=re.MULTILINE
    )
    
    # Comment out init() method's sentrylibrary usage and add pass statement
    # Match the init() method with its two-line body
    init_pattern = r'(\s+)def init\(self\):\s*\n(\s+)base = self\.python_requires\["sentrylibrary"\]\.module\.SentryLibrary\s*\n(\s+)self\.options\.update\(base\.options, base\.default_options\)'
    replacement = r'\1def init(self):\n\2# Sentry support disabled for Docker build (UltiMaker remote unreachable)\n\2# base = self.python_requires["sentrylibrary"].module.SentryLibrary\n\2# self.options.update(base.options, base.default_options)\n\2pass'
    
    if re.search(init_pattern, content, re.MULTILINE | re.DOTALL):
        content = re.sub(init_pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
    else:
        # Fallback: process line by line to be more robust
        lines = content.split('\n')
        new_lines = []
        i = 0
        while i < len(lines):
            line = lines[i]
            # Check if this is the init() method definition
            if re.match(r'\s+def init\(self\):', line):
                indent = len(line) - len(line.lstrip())
                new_lines.append(line)
                i += 1
                # Add comment and pass, skipping the original body lines
                new_lines.append(' ' * indent + '# Sentry support disabled for Docker build (UltiMaker remote unreachable)')
                # Skip the two body lines
                if i < len(lines) and 'python_requires["sentrylibrary"]' in lines[i]:
                    new_lines.append(' ' * indent + '# ' + lines[i].lstrip())
                    i += 1
                if i < len(lines) and 'self.options.update' in lines[i]:
                    new_lines.append(' ' * indent + '# ' + lines[i].lstrip())
                    i += 1
                # Add pass statement
                new_lines.append(' ' * indent + 'pass')
            else:
                new_lines.append(line)
                i += 1
        content = '\n'.join(new_lines)
    
    # Comment out setup_cmake_toolchain_sentry call
    content = re.sub(
        r'(\s+)self\.setup_cmake_toolchain_sentry\(tc\)',
        r'\1# self.setup_cmake_toolchain_sentry(tc)  # Disabled (UltiMaker remote unreachable)',
        content,
        flags=re.MULTILINE
    )
    
    # Comment out send_sentry_debug_files call
    content = re.sub(
        r'(\s+)self\.send_sentry_debug_files\(binary_basename="CuraEngine"\)',
        r'\1# self.send_sentry_debug_files(binary_basename="CuraEngine")  # Disabled (UltiMaker remote unreachable)',
        content,
        flags=re.MULTILINE
    )
    
    # Comment out npmpackage usage
    content = re.sub(
        r'(\s+)self\.python_requires\["npmpackage"\]\.module\.conf_package_json\(self\)',
        r'\1# self.python_requires["npmpackage"].module.conf_package_json(self)  # Disabled (UltiMaker remote unreachable)',
        content,
        flags=re.MULTILINE
    )
    
    with open(filename, 'w') as f:
        f.write(content)
    
    # Verify the patch worked
    if '# python_requires' in content or 'python_requires = []' in content:
        print(f"Successfully patched {filename}")
        print("  - python_requires commented out")
        if '# python_requires_extend' in content:
            print("  - python_requires_extend commented out")
        if '# base = self.python_requires' in content or '# Sentry support disabled' in content:
            print("  - init() method patched")
    else:
        print(f"WARNING: Patch may not have worked correctly for {filename}")
        print("  python_requires line may still be active")
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: patch_conanfile.py <conanfile.py>")
        sys.exit(1)
    
    patch_conanfile(sys.argv[1])

