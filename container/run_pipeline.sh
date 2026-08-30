#!/usr/bin/env bash
#
# Run Part1 in the development image with one set of options.
#
# Every pipeline run needs the same eight mounts, and getting one wrong fails in
# a way that looks like a pipeline bug: an absent host path becomes an empty
# directory over the image's copy, so mounting a checkout that does not exist
# silently deletes the package it was meant to replace.
#
# Usage:
#   run_pipeline.sh --name walinet-lcm --dat /path/to.dat --out /out/run1 \
#                   [--t1 /path/t1.mnc] [--] [extra Part1 arguments...]
#
# Everything after --, or after the recognised options, is passed to Part1
# verbatim, so the caller decides -S, -L, -Q, -w and the rest.
#
# Environment:
#   IMAGE        image to run              (default mrsi-pipeline:matlab-dev)
#   MRSI_JL      MRSI.jl checkout to mount (default ~/.julia/dev/MRSI, empty to skip)
#   PART1_SRC    Part1 files to overlay    (empty to use the image's own)
#   WALINET_SRC  walinet package to mount  (empty to use the image's own)
#   DATA_DIR     host dir mounted at /dats (default: the DAT's directory)
#   OUT_ROOT     host dir mounted at /out  (default: the output's parent)
#   BASIS, CTRL  LCModel basis and control file, as seen inside the container
set -euo pipefail

IMAGE="${IMAGE:-mrsi-pipeline:matlab-dev}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LICENCE="$REPO_ROOT/container/matlab_local/license.lic"
SHIMS="$REPO_ROOT/container/matlab_local/path/ToolboxCopies/IndividualFunctions"
MAC="${MAC:-02:42:ac:11:00:99}"

Name=""; Dat=""; T1=""; Out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) Name="$2"; shift 2;;
        --dat)  Dat="$2";  shift 2;;
        --t1)   T1="$2";   shift 2;;
        --out)  Out="$2";  shift 2;;
        --)     shift; break;;
        *)      break;;
    esac
done
[[ -n $Name && -n $Dat && -n $Out ]] || { echo "usage: run_pipeline.sh --name N --dat D --out O [--t1 T] [-- part1 args]" >&2; exit 2; }

# A mount source that does not exist is created by Docker as an empty directory
# and hides whatever the image had there. Refuse instead.
require_dir() { [[ -d "$1" ]] || { echo "ERROR: $2 does not exist: $1" >&2; exit 1; }; }
require_file() { [[ -f "$1" ]] || { echo "ERROR: $2 does not exist: $1" >&2; exit 1; }; }

require_file "$LICENCE" "the MATLAB licence"
require_file "$Dat" "the DAT"

DATA_DIR="${DATA_DIR:-$(dirname "$Dat")}"
OUT_ROOT="${OUT_ROOT:-$(dirname "$Out")}"
require_dir "$DATA_DIR" "the data directory"
mkdir -p "$OUT_ROOT"

# gpufit runs the same algorithm on the CPU when it sees no CUDA device, about an
# order of magnitude slower and with nothing but a log line to say so, so the
# device is requested explicitly and its absence is reported rather than assumed.
Gpu=()
if [[ "${USE_GPU:-auto}" != "no" ]] && command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    Gpu=(--gpus all)
else
    echo "NOTE: no GPU requested; a gpufit run will fall back to the CPU." >&2
fi

Mounts=(-v "$LICENCE:/opt/matlab/licenses/license.lic:ro")
[[ -d "$SHIMS" ]] && Mounts+=(-v "$SHIMS:/opt/matlab_path/ToolboxCopies/IndividualFunctions:ro")
Mounts+=(-v "$DATA_DIR:/dats:ro" -v "$OUT_ROOT:/out")

MRSI_JL="${MRSI_JL-$HOME/.julia/dev/MRSI}"
if [[ -n "$MRSI_JL" ]]; then
    require_dir "$MRSI_JL" "the MRSI.jl checkout"
    require_file "$MRSI_JL/Project.toml" "MRSI.jl's Project.toml"
    Mounts+=(-v "$MRSI_JL:/opt/MRSI.jl")
fi
if [[ -n "${WALINET_SRC:-}" ]]; then
    require_dir "$WALINET_SRC" "the walinet package"
    Mounts+=(-v "$WALINET_SRC:/opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/walinet/walinet:ro")
fi
if [[ -n "${PART1_SRC:-}" ]]; then
    require_dir "$PART1_SRC" "the Part1 source"
    for File in Part1_ProcessMRSI.sh run_matlab.sh run_julia_reco.jl julia_write_lcm_files.m \
                GetPar_CreateTempl_MaskPart1.m walinet_clean_csi.py run_deepmrsi.py; do
        [[ -f "$PART1_SRC/$File" ]] && Mounts+=(-v "$PART1_SRC/$File:/opt/Part1/$File:ro")
    done
fi

DatName=$(basename "$Dat")
OutName=$(basename "$Out")
T1Arg=()
[[ -n "$T1" ]] && T1Arg=(-t "/out/$(realpath --relative-to="$OUT_ROOT" "$T1")")

# The script goes into the output directory, which is already mounted, rather
# than a mktemp path mounted separately: Docker on Windows cannot resolve a
# POSIX temp path and silently creates a DIRECTORY at the target instead, so
# the run dies with "/run.sh: Is a directory".
Script="$OUT_ROOT/.run_${Name}.sh"
{
    echo '#!/bin/bash'
    echo "export JULIA_MRSI_PKG=/opt/julia_env"
    echo "julia --startup-file=no -e 'using Pkg; Pkg.activate(\"/opt/julia_env\"); Pkg.develop(path=\"/opt/MRSI.jl\"); Pkg.add(\"MAT\"); Pkg.resolve(); Pkg.precompile()' > /out/${OutName}_env.log 2>&1 || true"
    echo "rm -rf /out/$OutName; mkdir -p /out/$OutName"
    printf 'Part1_ProcessMRSI.sh -c /dats/%q %s -b %q -j %q -o /out/%q' \
        "$DatName" "${T1Arg[*]}" "${BASIS:-/opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/forD/data/basis/fid_1.300000ms.basis}" \
        "${CTRL:-/opt/Part1/ControlFiles/LCModel_Control_7T_3D_CRT_test_v1.m}" "$OutName"
    printf ' %s' "$@"
    printf ' > /out/%q/log.txt 2>&1\n' "$OutName"
    echo 'echo "PART1 EXIT = $?"'
} > "$Script"

echo "=== $Name ==="
echo "  dat : $Dat"
echo "  out : $Out"
echo "  args: $*"
docker rm -f "pipeline-$Name" >/dev/null 2>&1 || true
MSYS_NO_PATHCONV=1 docker run --rm --name "pipeline-$Name" \
    --mac-address "$MAC" ${Gpu[@]+"${Gpu[@]}"} "${Mounts[@]}" \
    "$IMAGE" bash "/out/.run_${Name}.sh"
rm -f "$Script"
