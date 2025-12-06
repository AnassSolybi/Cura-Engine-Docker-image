#  Copyright (c) 2024 UltiMaker
#  CuraEngine is released under the terms of the AGPLv3 or higher
#  Docker-specific version that handles UltiMaker dependencies gracefully
import os

from conan import ConanFile
from conan.errors import ConanInvalidConfiguration, ConanException
from conan.tools.build import check_min_cppstd
from conan.tools.cmake import CMakeToolchain, CMakeDeps, CMake, cmake_layout
from conan.tools.files import copy, mkdir, update_conandata
from conan.tools.microsoft import check_min_vs, is_msvc
from conan.tools.scm import Version, Git

required_conan_version = ">=2.7.0"


class CuraEngineDockerConan(ConanFile):
    name = "curaengine"
    license = "AGPL-3.0"
    author = "UltiMaker"
    url = "https://github.com/Ultimaker/CuraEngine"
    description = "Powerful, fast and robust engine for converting 3D models into g-code instructions for 3D printers. It is part of the larger open source project Cura."
    topics = ("cura", "protobuf", "gcode", "c++", "curaengine", "libarcus", "gcode-generation", "3D-printing")
    exports = "LICENSE*"
    settings = "os", "compiler", "build_type", "arch"
    package_type = "application"
    # No python_requires - Docker builds don't need Sentry support

    options = {
        "enable_arcus": [True, False],
        "enable_benchmarks": [True, False],
        "enable_extensive_warnings": [True, False],
        "enable_plugins": [True, False],
        "enable_remote_plugins": [True, False],
        "with_cura_resources": [True, False],
    }
    default_options = {
        "enable_arcus": True,
        "enable_benchmarks": False,
        "enable_extensive_warnings": False,
        "enable_plugins": True,
        "enable_remote_plugins": False,
        "with_cura_resources": False,
    }

    @property
    def _compilers_minimum_version(self):
        return {
            "gcc": "12",
            "clang": "14",
            "apple-clang": "13",
            "msvc": "191",
            "visual_studio": "17",
        }

    def init(self):
        # No Sentry support in Docker builds
        pass

    def set_version(self):
        if not self.version:
            self.version = self.conan_data["version"]

    def export(self):
        git = Git(self)
        update_conandata(self, {"version": self.version, "commit": git.get_commit()})

    def export_sources(self):
        copy(self, "CMakeLists.txt", self.recipe_folder, self.export_sources_folder)
        copy(self, "Cura.proto", self.recipe_folder, self.export_sources_folder)
        copy(self, "CuraEngine.ico", self.recipe_folder, self.export_sources_folder)
        copy(self, "CuraEngine.rc", self.recipe_folder, self.export_sources_folder)
        copy(self, "LICENSE", self.recipe_folder, self.export_sources_folder)
        copy(self, "*", os.path.join(self.recipe_folder, "src"), os.path.join(self.export_sources_folder, "src"))
        copy(self, "*", os.path.join(self.recipe_folder, "include"),
             os.path.join(self.export_sources_folder, "include"))
        # Note: benchmark, stress_benchmark, and tests are excluded for Docker builds

    def config_options(self):
        # No super().config_options() - we don't inherit from SentryLibrary
        if not self.options.enable_plugins:
            del self.options.enable_remote_plugins

    def configure(self):
        # No super().configure() - we don't inherit from SentryLibrary
        if self.options.enable_arcus or self.options.enable_plugins:
            self.options["protobuf"].shared = False
        if self.options.enable_arcus:
            # Try to configure arcus, but make it optional
            try:
                self.options["arcus"].shared = True
            except Exception:
                self.output.warn("Could not configure arcus options (may not be available)")
        # Force all libraries to be static for Emscripten builds
        if self.settings.os == "Emscripten":
            self.options["*"].shared = False

    def validate(self):
        # No super().validate() - we don't inherit from SentryLibrary
        if self.settings.compiler.get_safe("cppstd"):
            check_min_cppstd(self, 20)
        check_min_vs(self, 191)
        if not is_msvc(self):
            minimum_version = self._compilers_minimum_version.get(str(self.settings.compiler), False)
            if minimum_version and Version(self.settings.compiler.version) < minimum_version:
                raise ConanInvalidConfiguration(
                    f"{self.ref} requires C++{self._min_cppstd}, which your compiler does not support.")

    def build_requirements(self):
        self.test_requires("standardprojectsettings/[>=0.2.0]")
        if not self.conf.get("tools.build:skip_test", False, check_type=bool):
            self.test_requires("gtest/1.14.0")
        if self.options.enable_benchmarks:
            self.test_requires("benchmark/1.8.3")
            self.test_requires("docopt.cpp/0.6.3")

    def _require_with_fallback(self, ultimaker_req, fallback_req=None, package_name=None):
        """
        Require a package, using fallback mechanism for UltiMaker packages.
        For Docker builds, we use fallback versions (without @ultimaker) which will be
        resolved from ConanCenter or built from source with --build=missing.
        
        Args:
            ultimaker_req: The UltiMaker package requirement (e.g., "clipper/6.4.2@ultimaker/stable")
            fallback_req: The fallback requirement without @ultimaker (e.g., "clipper/6.4.2")
            package_name: Name of the package for logging (e.g., "clipper")
        """
        if fallback_req is None:
            # Extract package name and version from ultimaker_req
            parts = ultimaker_req.split("@")[0].split("/")
            if len(parts) >= 2:
                fallback_req = f"{parts[0]}/{parts[1]}"
            else:
                fallback_req = parts[0]
        
        if package_name is None:
            package_name = fallback_req.split("/")[0]
        
        # For Docker builds, always use fallback (without @ultimaker)
        # This allows Conan to find packages in ConanCenter or build from source
        # If UltiMaker remote is available and you want to use UltiMaker versions,
        # you can modify this to check for the remote, but for robustness, we use fallback
        self.output.info(f"Using package: {fallback_req} (Docker build - will try ConanCenter or build from source)")
        self.requires(fallback_req)

    def requirements(self):
        # Process requirements from conandata.yml, handling UltiMaker packages gracefully
        for req in self.conan_data["requirements"]:
            # Skip OneTBB for Emscripten builds (single-threaded)
            if req.startswith("onetbb/") and self.settings.arch == "wasm" and self.settings.os == "Emscripten":
                continue
            
            # Skip scripta - it's UltiMaker-specific and not available in ConanCenter
            # It's only used for logging/debugging, so we can build without it
            if "scripta" in req:
                self.output.warn(f"Skipping {req} - UltiMaker-specific package not available in ConanCenter")
                self.output.warn("scripta is only used for logging/debugging and is not required for production builds")
                continue
            
            # Handle UltiMaker packages with fallback
            if "@ultimaker" in req:
                parts = req.split("@")[0].split("/")
                package_name = parts[0] if parts else req.split("@")[0]
                fallback_req = req.split("@")[0]  # Remove @ultimaker reference
                self._require_with_fallback(req, fallback_req, package_name)
            else:
                # Non-UltiMaker packages - add directly
                self.requires(req)
        
        # Handle ARCUS requirements
        if self.options.enable_arcus:
            for req in self.conan_data["requirements_arcus"]:
                # arcus might be from UltiMaker, handle gracefully
                if "@ultimaker" in req:
                    fallback_req = req.split("@")[0]
                    self._require_with_fallback(req, fallback_req, "arcus")
                else:
                    self.requires(req)
        
        # Handle plugin requirements
        if self.options.enable_plugins:
            self.requires("neargye-semver/0.3.0")
            for req in self.conan_data["requirements_plugins"]:
                if "@ultimaker" in req:
                    fallback_req = req.split("@")[0]
                    self._require_with_fallback(req, fallback_req)
                else:
                    self.requires(req)
        
        # Handle cura resources
        if self.options.with_cura_resources:
            for req in self.conan_data["requirements_cura_resources"]:
                if "@ultimaker" in req:
                    fallback_req = req.split("@")[0]
                    self._require_with_fallback(req, fallback_req)
                else:
                    self.requires(req)
        
        # Hardcoded UltiMaker packages with fallbacks
        self._require_with_fallback(
            "clipper/6.4.2@ultimaker/stable",
            "clipper/6.4.2",
            "clipper"
        )
        
        # Standard dependencies (not from UltiMaker)
        self.requires("boost/1.86.0")
        self.requires("rapidjson/cci.20230929")
        self.requires("stb/cci.20230920")
        self.requires("spdlog/1.15.1")
        self.requires("fmt/11.1.3")
        self.requires("range-v3/0.12.0")
        self.requires("zlib/1.3.1")
        
        # mapbox-wagyu with fallback
        self._require_with_fallback(
            "mapbox-wagyu/0.5.0@ultimaker/stable",
            "mapbox-wagyu/0.5.0",
            "mapbox-wagyu"
        )

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()

        tc = CMakeToolchain(self)

        tc.preprocessor_definitions["_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR"] = 1

        tc.variables["CURA_ENGINE_VERSION"] = self.version
        tc.variables["CURA_ENGINE_HASH"] = self.conan_data["commit"]
        tc.variables["ENABLE_ARCUS"] = self.options.enable_arcus
        tc.variables["ENABLE_TESTING"] = not self.conf.get("tools.build:skip_test", False, check_type=bool)
        tc.variables["ENABLE_BENCHMARKS"] = self.options.enable_benchmarks
        tc.variables["EXTENSIVE_WARNINGS"] = self.options.enable_extensive_warnings
        tc.variables["OLDER_APPLE_CLANG"] = self.settings.compiler == "apple-clang" and Version(
            self.settings.compiler.version) < "14"
        tc.variables["ENABLE_THREADING"] = not (self.settings.arch == "wasm" and self.settings.os == "Emscripten")
        if self.options.enable_plugins:
            tc.variables["ENABLE_PLUGINS"] = True
            tc.variables["ENABLE_REMOTE_PLUGINS"] = self.options.enable_remote_plugins
        else:
            tc.variables["ENABLE_PLUGINS"] = self.options.enable_plugins
        
        # No setup_cmake_toolchain_sentry - Sentry support disabled in Docker builds
        tc.generate()

        for dep in self.dependencies.values():
            if len(dep.cpp_info.libdirs) > 0:
                copy(self, "*.dylib", dep.cpp_info.libdirs[0], self.build_folder)
                copy(self, "*.dll", dep.cpp_info.libdirs[0], self.build_folder)
            if len(dep.cpp_info.bindirs) > 0:
                copy(self, "*.dll", dep.cpp_info.bindirs[0], self.build_folder)

            folder_dists = []
            if not self.conf.get("tools.build:skip_test", False, check_type=bool):
                folder_dists.append("tests")
            if self.options.enable_benchmarks:
                folder_dists.append("benchmark")
                folder_dists.append("stress_benchmark")

            for dist_folder in folder_dists:
                dist_path = os.path.join(self.build_folder, dist_folder)
                if not os.path.exists(dist_path):
                    mkdir(self, dist_path)
                if len(dep.cpp_info.libdirs) > 0:
                    copy(self, "*.dylib", dep.cpp_info.libdirs[0], os.path.join(self.build_folder, dist_folder))
                    copy(self, "*.dll", dep.cpp_info.libdirs[0], os.path.join(self.build_folder, dist_folder))
                if len(dep.cpp_info.bindirs) > 0:
                    copy(self, "*.dll", dep.cpp_info.bindirs[0], os.path.join(self.build_folder, dist_folder))

    def layout(self):
        cmake_layout(self)
        self.cpp.build.includedirs = ["."]  # To package the generated headers
        self.cpp.package.libs = ["_CuraEngine"]

        if self.settings.os == "Emscripten":
            self.cpp.build.bin = ["CuraEngine.js"]
            self.cpp.package.bin = ["CuraEngine.js"]
            self.cpp.build.bindirs += ["CuraEngine"]

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()
        
        # No send_sentry_debug_files - Sentry support disabled in Docker builds

    def deploy(self):
        copy(self, "CuraEngine*", src=os.path.join(self.package_folder, "bin"), dst=self.deploy_folder)

    def package(self):
        match self.settings.os:
            case "Windows":
                ext = ".exe"
            case "Emscripten":
                ext = ".js"
            case other:
                ext = ""
        copy(self, f"CuraEngine{ext}", src=self.build_folder, dst=os.path.join(self.package_folder, "bin"))
        copy(self, f"*.d.ts", src=self.build_folder, dst=os.path.join(self.package_folder, "bin"))
        copy(self, f"_CuraEngine.*", src=self.build_folder, dst=os.path.join(self.package_folder, "lib"))
        copy(self, "LICENSE*", src=self.source_folder, dst=os.path.join(self.package_folder, "license"))

    def package_info(self):
        ext = ".exe" if self.settings.os == "Windows" else ""
        self.conf_info.define_path("user.curaengine:curaengine",
                                   os.path.join(self.package_folder, "bin", f"CuraEngine{ext}"))

        # No npmpackage handling - Emscripten builds not typically used in Docker

