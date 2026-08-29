#!/usr/bin/env bash
#
# Compile Part1's MATLAB entry points into standalone binaries.
#
# Runs inside the development image, which is the only place that has both the
# sources and mcc. The binaries it writes are what a deployment runs against the
# MATLAB Runtime, with no MATLAB licence.
#
# Usage (from the host):
#   ./container/matlab_shell.sh bash /opt/tools/compile_matlab.sh
#
# Environment:
#   PART1_DIR   Part1 checkout                (default /opt/Part1)
#   OUT_DIR     where the binaries land       (default $PART1_DIR/Matlab_Compiled)
#   MATLAB_DIR  MATLAB install                (default /opt/matlab)
#   SHIM_DIR    local toolbox replacements    (default /opt/matlab_path)
#   ENTRIES     space separated entry points  (default: all five)
#
# The shims are not optional. A compiled binary never runs startup.m, so the
# addpath that makes de2bi, nanmean, nanmedian, mad, prctile and vrrotvec
# resolvable at development time does not happen for it. They have to be baked in
# with -a or the binary fails at the first call, at run time, on the scanner.
set -euo pipefail

PART1_DIR="${PART1_DIR:-/opt/Part1}"
OUT_DIR="${OUT_DIR:-$PART1_DIR/Matlab_Compiled}"
MATLAB_DIR="${MATLAB_DIR:-/opt/matlab}"
SHIM_DIR="${SHIM_DIR:-/opt/matlab_path}"
ENTRIES="${ENTRIES:-ExtractBrain_mask flip_mask GetPar_CreateTempl_MaskPart1 MRSI_Reconstruction julia_write_lcm_files}"

MCC="$MATLAB_DIR/bin/mcc"

if [[ ! -x "$MCC" ]]; then
    echo "ERROR: no mcc at $MCC." >&2
    echo "       MATLAB_Compiler has to be in MATLAB_PRODUCTS when the image is built." >&2
    exit 1
fi

ADD_PATHS=()
[[ -d "$PART1_DIR/MatlabFunctions" ]] && ADD_PATHS+=(-a "$PART1_DIR/MatlabFunctions")
[[ -d "$SHIM_DIR" ]] && ADD_PATHS+=(-a "$SHIM_DIR")

mkdir -p "$OUT_DIR"
echo "Compiling into $OUT_DIR"
echo "Bundling: ${ADD_PATHS[*]:-nothing}"
echo

Failed=()
for Entry in $ENTRIES; do
    Source="$PART1_DIR/$Entry.m"
    if [[ ! -f "$Source" ]]; then
        echo "SKIP  $Entry: no $Source"
        Failed+=("$Entry (no source)")
        continue
    fi
    echo "=== $Entry ==="
    if "$MCC" -m "$Source" "${ADD_PATHS[@]}" -d "$OUT_DIR" -v; then
        if [[ -x "$OUT_DIR/$Entry" ]]; then
            echo "OK    $Entry -> $OUT_DIR/$Entry"
        else
            echo "FAIL  $Entry: mcc returned 0 but produced no binary"
            Failed+=("$Entry (no binary)")
        fi
    else
        echo "FAIL  $Entry: mcc failed"
        Failed+=("$Entry (mcc failed)")
    fi
    echo
done

if (( ${#Failed[@]} )); then
    echo "FAILED: ${Failed[*]}" >&2
    exit 1
fi

echo "All entry points compiled."
ls -la "$OUT_DIR"
