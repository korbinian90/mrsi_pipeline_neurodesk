#!/usr/bin/env bash
#
# Compile Part1's MATLAB entry points, inside the development image.
#
# Part1 owns the recipe: compile.m lists the entry points, assembles the
# AdditionalFiles set, and excludes the six files in MatlabFunctions that do not
# parse (one of them, RatioMapsExcludeHighValues_1_0.m, has an unclosed paren at
# line 117). Duplicating that here would drift, so this only sets up what
# compile.m assumes and then runs it.
#
# The one thing compile.m cannot do for itself: it bundles
# MatlabFunctions/ToolboxCopies/IndividualFunctions, which is empty in a
# deployment. The replacements for the toolbox functions this licence does not
# cover live outside Part1, and a compiled binary never runs startup.m, so
# without staging them in the binary fails at its first de2bi or nanmean call,
# at run time.
#
# Usage (from the host):
#   ./container/matlab_shell.sh bash /opt/tools/compile_matlab.sh
#
# Environment:
#   PART1_DIR  Part1 checkout            (default /opt/Part1)
#   OUT_DIR    where the binaries land   (default $PART1_DIR/Matlab_Compiled)
#   SHIM_DIR   toolbox replacements      (default /opt/matlab_path/ToolboxCopies/IndividualFunctions)
#   MATLAB_DIR MATLAB install            (default /opt/matlab)
set -euo pipefail

PART1_DIR="${PART1_DIR:-/opt/Part1}"
OUT_DIR="${OUT_DIR:-$PART1_DIR/Matlab_Compiled}"
SHIM_DIR="${SHIM_DIR:-/opt/matlab_path/ToolboxCopies/IndividualFunctions}"
MATLAB_DIR="${MATLAB_DIR:-/opt/matlab}"

EXPECTED=(GetPar_CreateTempl_MaskPart1 MRSI_Reconstruction julia_write_lcm_files ExtractBrain_mask flip_mask)

if [[ ! -x "$MATLAB_DIR/bin/mcc" ]]; then
    echo "ERROR: no mcc at $MATLAB_DIR/bin/mcc." >&2
    echo "       MATLAB_Compiler has to be in MATLAB_PRODUCTS when the image is built." >&2
    exit 1
fi
[[ -f "$PART1_DIR/compile.m" ]] || { echo "ERROR: no $PART1_DIR/compile.m." >&2; exit 1; }

BundleDir="$PART1_DIR/MatlabFunctions/ToolboxCopies/IndividualFunctions"
mkdir -p "$BundleDir"
if [[ -d "$SHIM_DIR" ]]; then
    cp -a "$SHIM_DIR/." "$BundleDir/"
    echo "Staged toolbox replacements into $BundleDir:"
    ls "$BundleDir" | sed 's/^/  /'
else
    echo "WARNING: no $SHIM_DIR; the binaries will not carry the toolbox replacements" >&2
    echo "         and will fail at the first call to one of them." >&2
fi
echo

cd "$PART1_DIR"
"$MATLAB_DIR/bin/matlab" -nodisplay -batch "run('$PART1_DIR/compile.m')" || true

echo
echo "=== results ==="
Missing=()
for Entry in "${EXPECTED[@]}"; do
    if [[ -x "$OUT_DIR/$Entry" ]]; then
        printf '  OK    %-32s %s\n' "$Entry" "$(stat -c %s "$OUT_DIR/$Entry") bytes"
    else
        printf '  FAIL  %-32s not produced\n' "$Entry"
        Missing+=("$Entry")
    fi
done

if (( ${#Missing[@]} )); then
    echo
    echo "MISSING: ${Missing[*]}" >&2
    exit 1
fi
echo
echo "All ${#EXPECTED[@]} entry points compiled into $OUT_DIR."
