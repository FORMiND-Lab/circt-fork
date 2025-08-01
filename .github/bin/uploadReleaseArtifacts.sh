#!/usr/bin/env bash

set -eo pipefail

# Fixed configuration for release events only
OPT_ASSERTIONS=OFF
OPT_CMAKE_BUILD_TYPE=release
OPT_OS=("linux" "macos" "windows")
OPT_RUN_TESTS=true

#-------------------------------------------------------------------------------
# JSON snippets used to configure downstream workflows
#-------------------------------------------------------------------------------

# Configuration snippets for a run of the native runner UBTI script.
configLinuxRunner=$(cat <<EOF
[
  {
    "runner": "ubuntu-24.04",
    "cmake_c_compiler": "clang",
    "cmake_cxx_compiler": "clang++"
  }
]
EOF
)
configMacOsRunner=$(cat <<EOF
[
  {
    "runner": "macos-13",
    "cmake_c_compiler": "clang",
    "cmake_cxx_compiler": "clang++"
  }
]
EOF
)
configWindowsRunner=$(cat <<EOF
[
  {
    "runner": "windows-2022",
    "cmake_c_compiler": "cl",
    "cmake_cxx_compiler": "cl"
  }
]
EOF
)

# Configuration snippets for building something on the native UBTI workflow.
configNativeFullShared=$(cat <<EOF
[
  {
    "name":"CIRCT-full shared",
    "install_target":"install",
    "package_name_prefix":"circt-full-shared",
    "cmake_build_type":"$OPT_CMAKE_BUILD_TYPE",
    "llvm_enable_assertions":"$OPT_ASSERTIONS",
    "build_shared_libs":"ON",
    "llvm_force_enable_stats":"ON",
    "run_tests": $OPT_RUN_TESTS
  }
]
EOF
)
configNativeFullStatic=$(cat <<EOF
[
  {
    "name":"CIRCT-full static",
    "install_target":"install",
    "package_name_prefix":"circt-full-static",
    "cmake_build_type":"$OPT_CMAKE_BUILD_TYPE",
    "llvm_enable_assertions":"$OPT_ASSERTIONS",
    "build_shared_libs":"OFF",
    "llvm_force_enable_stats":"ON",
    "run_tests": $OPT_RUN_TESTS
  }
]
EOF
)

#-------------------------------------------------------------------------------
# Build the JSON payload that will be used to configure UBTI and UBTI-static.
#-------------------------------------------------------------------------------

# Only native builds - no static builds needed
config=$(cat <<EOF
{
  "static": [],
  "native": []
}
EOF
)
for os in "${OPT_OS[@]}"; do
  case "$os" in
    # Linux gets: Native full shared and full static
    "linux")
      native=$(echo "$configNativeFullShared" "$configNativeFullStatic" | jq -s 'add')
      native=$(echo "$native" "$configLinuxRunner" | jq -s '[combinations | add]')
      config=$(echo "$config" | jq '.native += $a' --argjson a "$native")
      ;;
    # MacOS gets: Native full shared and full static
    "macos")
      native=$(echo "$configNativeFullShared" "$configNativeFullStatic" | jq -s 'add')
      native=$(echo "$native" "$configMacOsRunner" | jq -s '[combinations | add]')
      config=$(echo "$config" | jq '.native += $a' --argjson a "$native")
      ;;
    # Windows gets: Native full static only (Windows cannot handle full shared)
    "windows")
      native=$(echo "$configNativeFullStatic" | jq -s 'add')
      native=$(echo "$native" "$configWindowsRunner" | jq -s '[combinations | add]')
      config=$(echo "$config" | jq '.native += $a' --argjson a "$native")
      ;;
    *)
      echo "unknown os '$os'"
      exit 1
      ;;
  esac
done

# Return the final `config` JSON.
echo "$config" 