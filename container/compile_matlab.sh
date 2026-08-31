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
#   OVERLAY    MatlabFunctions overlay   (default /opt/matlab_path)
#   MATLAB_DIR MATLAB install            (default /opt/matlab)
set -euo pipefail

PART1_DIR="${PART1_DIR:-/opt/Part1}"
OUT_DIR="${OUT_DIR:-$PART1_DIR/Matlab_Compiled}"
OVERLAY="${OVERLAY:-/opt/matlab_path}"
MATLAB_DIR="${MATLAB_DIR:-/opt/matlab}"

EXPECTED=(GetPar_CreateTempl_MaskPart1 MRSI_Reconstruction julia_write_lcm_files ExtractBrain_mask flip_mask)

if [[ ! -x "$MATLAB_DIR/bin/mcc" ]]; then
    echo "ERROR: no mcc at $MATLAB_DIR/bin/mcc." >&2
    echo "       MATLAB_Compiler has to be in MATLAB_PRODUCTS when the image is built." >&2
    exit 1
fi
[[ -f "$PART1_DIR/compile.m" ]] || { echo "ERROR: no $PART1_DIR/compile.m." >&2; exit 1; }

# A licence that did not mount lands here as a directory rather than a file, and
# MATLAB then reports "License Manager Error -1 ... System Error: 2", which reads
# as a licensing problem and is not one. Say what it is instead.
Licence="$MATLAB_DIR/licenses/license.lic"
if [[ -e "$Licence" && ! -s "$Licence" ]]; then
    echo "ERROR: $Licence is not a file. A -v mount whose source does not exist" >&2
    echo "       is created by Docker as an empty directory. Mount the licence from" >&2
    echo "       the main checkout: container/matlab_local/ is gitignored, so a git" >&2
    echo "       worktree of this repository does not have it." >&2
    exit 1
fi

# Compile from the container's own filesystem, never from the caller's mount.
# mcc against a -v mounted checkout ran at 14% of one core and produced nothing in
# 37 minutes, against about two minutes from a local tree, so this is not a tidiness
# preference. The build writes into the tree as well, which a read-only mount would
# refuse. Set COPY_SOURCE=no to compile in place.
if [[ "${COPY_SOURCE:-yes}" != "no" ]]; then
    Local=$(mktemp -d)/Part1
    echo "Copying $PART1_DIR into the container filesystem"
    cp -a "$PART1_DIR" "$Local"
    rm -rf "$Local/.git"
    PART1_DIR="$Local"
fi

# The image's MatlabFunctions holds only MRSIMatlabFunctions. compile.m also
# names ToolboxCopies/IndividualFunctions and four MatlabFunctions_3rdParty
# packages, and refuses outright when one is missing, so the overlay that supplies
# them at run time is staged into the same tree before compiling.
Target="$PART1_DIR/MatlabFunctions"
mkdir -p "$Target"
if [[ -d "$OVERLAY" ]]; then
    cp -a "$OVERLAY/." "$Target/"
    echo "Staged the MatlabFunctions overlay from $OVERLAY:"
    ls "$Target" | sed 's/^/  /'
else
    echo "WARNING: no $OVERLAY. compile.m names files it supplies and will refuse," >&2
    echo "         and any binary that did build would fail at its first de2bi call." >&2
fi
echo

cd "$PART1_DIR"
"$MATLAB_DIR/bin/matlab" -nodisplay -batch "run('$PART1_DIR/compile.m')" || true

# compile.m writes to a relative OutputDir ('Matlab_Compiled'), so the binaries
# land beside the sources whatever OUT_DIR says. Collect them, rather than
# editing Part1's recipe to take a path from us.
BuiltDir="$PART1_DIR/Matlab_Compiled"
if [[ "$BuiltDir" != "$OUT_DIR" && -d "$BuiltDir" ]]; then
    mkdir -p "$OUT_DIR"
    cp -a "$BuiltDir/." "$OUT_DIR/"
    echo "Collected $BuiltDir -> $OUT_DIR"
fi

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
