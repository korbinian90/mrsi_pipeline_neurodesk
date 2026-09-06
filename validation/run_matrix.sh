#!/usr/bin/env bash
#
# Run one Part1 configuration in the shipping image, mounting data only.
#
# No source mounts: the point is to exercise the image as the collaborator will
# receive it. Anything that needs a host checkout to work is a packaging defect,
# not a run to record as green.
#
# Usage: run_matrix.sh <name> <dat> <out_root> [-- part1 args...]
#
# Environment:
#   IMAGE     image under test   (default mrsi-pipeline:7t)
#   BASIS     LCModel basis, as seen inside the container
#   CTRL      LCModel control file, as seen inside the container
#   USE_GPU   "no" to run without --gpus all
set -euo pipefail

IMAGE="${IMAGE:-mrsi-pipeline:7t-rc3}"
BASIS="${BASIS:-/opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/forD/data/basis/fid_1.300000ms.basis}"
CTRL="${CTRL:-/opt/Part1/ControlFiles/LCModel_Control_7T_3D_CRT_test_v1.m}"

Name=$1; Dat=$2; OutRoot=$3; shift 3
[[ "${1:-}" == "--" ]] && shift

[[ -f "$Dat" ]] || { echo "ERROR: no DAT at $Dat" >&2; exit 1; }
mkdir -p "$OutRoot"
DataDir=$(dirname "$Dat")
DatName=$(basename "$Dat")

# PART1_SRC mounts Part1's shell and MATLAB-side scripts over the image's copy.
# It exists to iterate on a fix without a fifteen minute rebuild, and a run made
# with it set proves nothing about the shipped container: the acceptance run is
# the one with data mounts only.
Src=()
if [[ -n "${PART1_SRC:-}" ]]; then
    echo "WARNING: PART1_SRC is set, so this run does NOT test the image as shipped." >&2
    for File in Part1_ProcessMRSI.sh run_matlab.sh create_mask.sh InstallProgramPaths.sh \
                run_julia_reco.jl walinet_clean_csi.py run_deepmrsi.py processing_record.py \
                run_lcmodel_files.sh; do
        [[ -f "$PART1_SRC/$File" ]] && Src+=(-v "$PART1_SRC/$File:/opt/Part1/$File:ro")
    done
fi

# DEEPFIRE_SRC does the same for the installed python packages: point it at a
# MRSIdeepFIRE checkout's DEEP_CRT_MRSI/install. Same caveat as PART1_SRC, a run
# with it set is an iteration and not an acceptance.
if [[ -n "${DEEPFIRE_SRC:-}" ]]; then
    echo "WARNING: DEEPFIRE_SRC is set, so this run does NOT test the image as shipped." >&2
    Pkg=/opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install
    # Directory mounts, except walinet: walinet/models holds the trained weights,
    # which ship separately and are not in a checkout, so mounting that directory
    # would hide them and every model would look uninstalled. Its own sources are
    # few enough to mount one by one.
    for Package in deep_crt_mrsi mrs_utils forD forD_gpu_fit; do
        [[ -d "$DEEPFIRE_SRC/$Package/$Package" ]] &&
            Src+=(-v "$DEEPFIRE_SRC/$Package/$Package:$Pkg/$Package/$Package:ro")
    done
    Walinet="$DEEPFIRE_SRC/walinet/walinet"
    if [[ -d "$Walinet" ]]; then
        while IFS= read -r File; do
            Src+=(-v "$File:$Pkg/walinet/walinet/${File#"$Walinet/"}:ro")
        done < <(find "$Walinet" -name '*.py' -not -path '*/models/*')
    fi
fi

Gpu=()
if [[ "${USE_GPU:-auto}" != "no" ]] && nvidia-smi -L >/dev/null 2>&1; then
    Gpu=(--gpus all)
else
    echo "NOTE: running without a GPU; gpufit will fall back to the CPU." >&2
fi

# The script is written into the mounted output directory rather than passed as
# a bind mount: Docker on Windows turns a POSIX temp path into a directory at
# the target and the run dies with "Is a directory".
Script="$OutRoot/.run_${Name}.sh"
{
    echo '#!/bin/bash'
    echo "rm -rf /out/$Name; mkdir -p /out/$Name"
    printf 'Part1_ProcessMRSI.sh -c /dats/%q -b %q -j %q -o /out/%q' \
        "$DatName" "$BASIS" "$CTRL" "$Name"
    for arg in "$@"; do printf ' %q' "$arg"; done
    printf ' > /out/%q/log.txt 2>&1\n' "$Name"
    echo 'Status=$?'
    echo 'echo "PART1 EXIT = $Status"'
    echo 'exit $Status'
} > "$Script"

echo "=== $Name ==="
echo "  image: $IMAGE"
echo "  dat  : $Dat"
echo "  args : $*"
Start=$(date +%s)
set +e
MSYS_NO_PATHCONV=1 docker run --rm --name "matrix-$Name" \
    ${Gpu[@]+"${Gpu[@]}"}     ${Env[@]+"${Env[@]}"} \
    ${Src[@]+"${Src[@]}"} \
    -v "$DataDir:/dats:ro" -v "$OutRoot:/out" \
    --entrypoint bash "$IMAGE" "/out/.run_${Name}.sh"
Exit=$?
set -e
Elapsed=$(( $(date +%s) - Start ))
rm -f "$Script"

# A run that produced no outputs is the case most worth recording, and it is also
# the one where the count fails: an absent directory makes find exit non-zero and
# pipefail plus set -e then take the whole script with it before it can report.
count() { { find "$1" -maxdepth 1 -name "$2" 2>/dev/null || true; } | wc -l; }

# Which reconstruction actually ran is not visible in the exit code, so record
# it. An image whose Part1 still falls back to MATLAB reports success for a
# broken Julia route, which is exactly what this column is here to catch.
Route="-"
if [[ " $* " == *" -S "* ]]; then
    if grep -qa "Use the MATLAB reconstruction instead" "$OutRoot/$Name/log.txt" 2>/dev/null; then
        Route="FELLBACK"
        echo "  WARNING: -S was asked for and the run fell back to the MATLAB reconstruction." >&2
    else
        Route="julia"
    fi
fi
Fits=$(count "$OutRoot/$Name/spectra" '*.table')
Deep=$(count "$OutRoot/$Name/deepMRSI" '*.nii.gz')
printf '%s\texit=%d\troute=%s\tlcm_tables=%d\tdeep_niftis=%d\t%ds\n' \
    "$Name" "$Exit" "$Route" "$Fits" "$Deep" "$Elapsed" | tee -a "$OutRoot/matrix_results.tsv"
