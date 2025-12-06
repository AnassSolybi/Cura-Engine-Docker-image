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
    
    # Comment out init() method's sentrylibrary usage
    content = re.sub(
        r'(\s+)def init\(self\):\s*\n(\s+)base = self\.python_requires\["sentrylibrary"\]\.module\.SentryLibrary\s*\n(\s+)self\.options\.update\(base\.options, base\.default_options\)',
        r'\1def init(self):\n\2# Sentry support disabled for Docker build (UltiMaker remote unreachable)\n\2# base = self.python_requires["sentrylibrary"].module.SentryLibrary\n\2# self.options.update(base.options, base.default_options)',
        content,
        flags=re.MULTILINE
    )
    
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
    
    print(f"Successfully patched {filename}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: patch_conanfile.py <conanfile.py>")
        sys.exit(1)
    
    patch_conanfile(sys.argv[1])

