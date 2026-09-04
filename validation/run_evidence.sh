#!/usr/bin/env bash
#
# Pull the lines that say what a run actually did out of its log.
#
# The pipeline is quiet about which branch it took, so a run is only readable
# through a handful of lines scattered over a hundred thousand. This collects
# them in one place: the invocation, the mask decision, the reconstruction
# size, the WALINET crop, every B0 decision, and the fitter's landmark line.
#
# Usage: run_evidence.sh <run output directory>
set -uo pipefail

Dir=$1
Log="$Dir/log.txt"
[[ -f "$Log" ]] || { echo "no log.txt in $Dir" >&2; exit 1; }

echo "=== $Dir ==="
echo "-- invocation"
grep -a "Part1_ProcessMRSI.sh " "$Log" | head -1

echo "-- mask"
grep -aE "^Mask flag:|mask_flag:" "$Log" | head -2

echo "-- reconstruction and crop"
grep -aE "reconstruction done, CSI size|walinet_clean_csi:|run_deepmrsi: fid shape" "$Log"

echo "-- B0 decisions"
grep -aE "B0 correction:|B0 map from|estimating the B0 map|gpufit landmark B0 search|landmark B0 correction|gpufit landmark map omitted|gpufit constant frequency" "$Log"

echo "-- maps"
if [[ -d "$Dir/deepMRSI" ]]; then
    printf '   %d NIfTI files\n' "$(find "$Dir/deepMRSI" -maxdepth 1 -name '*.nii.gz' | wc -l)"
    ls "$Dir/deepMRSI" | grep -E "B0|landmark" | sed 's/^/   /'
else
    echo "   no deepMRSI directory"
fi
echo
