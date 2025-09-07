#!/bin/bash

# Script to check for required tools for NanoPi Alpine Linux build
# Exit codes: 0 = all tools found, 1 = missing tools

set -euo pipefail

CROSS_COMPILER="${CROSS_COMPILE}gcc"

missing_tools=()
found_tools=()

# Core build tools required
required_tools="gcc make tar sed grep wget sfdisk mkfs.ext4 losetup"

echo "Checking for required build tools..."

# Check for kpartx or partx (disk partitioning tools)
kpartx_path=$(which kpartx 2>/dev/null || true)
partx_path=$(which partx 2>/dev/null || true)

if [ -z "$kpartx_path" ] && [ -z "$partx_path" ]; then
    missing_tools+=("kpartx or partx")
else
    if [ -n "$kpartx_path" ]; then
        found_tools+=("kpartx")
    else
        found_tools+=("partx")
    fi
fi

# Check each required tool
for tool in $required_tools; do
    tool_path=$(which "$tool" 2>/dev/null || true)
    if [ -z "$tool_path" ]; then
        missing_tools+=("$tool")
    else
        found_tools+=("$tool")
    fi
done

# Check for cross-compiler
cross_compiler_path=$(which "$CROSS_COMPILER" 2>/dev/null || true)
if [ -z "$cross_compiler_path" ]; then
    # Try to find any ARM cross-compiler as fallback
    gcc_dir=$(dirname "$(which gcc 2>/dev/null || echo '/usr/bin')")
    arm_gcc_candidates=$(ls "$gcc_dir"/arm-*-gcc 2>/dev/null || true)
    
    if [ -z "$arm_gcc_candidates" ]; then
        missing_tools+=("$CROSS_COMPILER (or any arm-*-gcc)")
    else
        # Found alternative ARM cross-compiler
        alt_compiler=$(echo "$arm_gcc_candidates" | head -n1)
        found_tools+=("$(basename "$alt_compiler") (alternative to $CROSS_COMPILER)")
    fi
else
    found_tools+=("$CROSS_COMPILER")
fi

# Report results
echo
echo "=== Tool Check Results ==="

if [ ${#found_tools[@]} -gt 0 ]; then
    echo "✓ Found tools (${#found_tools[@]}):"
    printf "  %s\n" "${found_tools[@]}"
fi

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo
    echo "✗ Missing tools (${#missing_tools[@]}):"
    printf "  %s\n" "${missing_tools[@]}"
    echo
    echo "Please install the missing tools before proceeding with the build."
    exit 1
fi

echo
echo "✓ All required tools are available. Ready to proceed with build!"
